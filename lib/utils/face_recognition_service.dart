import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceRecognitionService {
  FaceRecognitionService._();
  static final FaceRecognitionService instance = FaceRecognitionService._();

  static const _kTemplateKey = 'face_template_v3';
  // Older keys from earlier (looser) cuts of the feature; cleared on enrollment.
  static const _kLegacyKeys = ['face_template_v2', 'face_template_v1'];

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Hard ceiling on the verify distance. The effective threshold is the
  /// smaller of this and `enrollSpread + _spreadMargin`, so a tight enrollment
  /// makes matching *stricter*, never looser.
  static const double matchThreshold = 0.05;
  static const double _spreadMargin = 0.012;

  /// Face readings collected during enrollment before building the template.
  static const int enrollSamples = 5;
  static const int minEnrollSamples = 3;

  static const double enrollConsistency = 0.075;

  /// Matching frames required (during verification) before the app unlocks.
  static const int verifyMatchesRequired = 3;

  /// Reject a captured frame whose face detection is this incomplete (too many
  /// missing contours/landmarks => the signature would be mostly placeholder
  /// values and could falsely match another low-quality capture).
  static const int _maxMissingFeatures = 5; // out of 13 contours + 4 landmarks

  FaceDetector? _detector;
  FaceDetector get _faceDetector => _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.15,
        ),
      );

  Future<void> dispose() async {
    try {
      await _detector?.close();
    } catch (_) {}
    _detector = null;
  }

  Future<bool> isEnrolled() async {
    try {
      final v = await _secure.read(key: _kTemplateKey);
      return v != null && v.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearEnrollment() async {
    for (final k in [_kTemplateKey, ..._kLegacyKeys]) {
      try {
        await _secure.delete(key: k);
      } catch (_) {}
    }
  }

  /// Runs ML Kit on a captured photo file and, if a single clear, frontal face
  /// is found, returns its normalized signature vector. On any quality problem
  /// returns `(vector: null, error: <hint>)`.
  Future<({List<double>? vector, String? error})> signatureFromImageFile(
    String path,
  ) async {
    List<Face> faces;
    try {
      faces = await _faceDetector.processImage(InputImage.fromFilePath(path));
    } catch (_) {
      return (vector: null, error: 'Could not analyse the camera image.');
    }
    if (faces.isEmpty) {
      return (vector: null, error: 'No face detected — center your face.');
    }
    faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    final face = faces.first;
    if (faces.length > 1) {
      final second = faces[1];
      final dominant = (face.boundingBox.width * face.boundingBox.height) >
          (second.boundingBox.width * second.boundingBox.height) * 2.0;
      if (!dominant) {
        return (vector: null, error: 'More than one face in view.');
      }
    }

    final ey = (face.headEulerAngleY ?? 0).abs();
    final ez = (face.headEulerAngleZ ?? 0).abs();
    final ex = (face.headEulerAngleX ?? 0).abs();
    if (ey > 18 || ez > 18 || ex > 22) {
      return (vector: null, error: 'Look straight at the camera.');
    }

    final vec = _buildVector(face);
    if (vec == null) {
      return (vector: null, error: 'Move closer, in good light, and hold steady.');
    }
    return (vector: vec, error: null);
  }

  // Ordered plan: each contour resampled to a fixed number of points so the
  // signature vector is always the same length regardless of what ML Kit
  // returns. Missing/short contours are filled with a deterministic fallback
  // (and a frame with too many of them is rejected — see _maxMissingFeatures).
  static const Map<FaceContourType, int> _contourPlan = {
    FaceContourType.face: 18,
    FaceContourType.leftEyebrowTop: 5,
    FaceContourType.leftEyebrowBottom: 4,
    FaceContourType.rightEyebrowTop: 5,
    FaceContourType.rightEyebrowBottom: 4,
    FaceContourType.leftEye: 8,
    FaceContourType.rightEye: 8,
    FaceContourType.noseBridge: 4,
    FaceContourType.noseBottom: 5,
    FaceContourType.upperLipTop: 6,
    FaceContourType.upperLipBottom: 5,
    FaceContourType.lowerLipTop: 5,
    FaceContourType.lowerLipBottom: 6,
  };

  static const List<FaceLandmarkType> _landmarkPlan = [
    FaceLandmarkType.noseBase,
    FaceLandmarkType.bottomMouth,
    FaceLandmarkType.leftCheek,
    FaceLandmarkType.rightCheek,
  ];

  List<double>? _buildVector(Face face) {
    // Normalization frame: midpoint of the two eyes; x-axis along eye line;
    // scale = inter-ocular distance. Prefer eye-contour centroids (more
    // stable), fall back to the eye landmarks.
    final eyeL =
        _eyePoint(face, FaceContourType.leftEye, FaceLandmarkType.leftEye);
    final eyeR =
        _eyePoint(face, FaceContourType.rightEye, FaceLandmarkType.rightEye);
    if (eyeL == null || eyeR == null) return null;

    final midX = (eyeL[0] + eyeR[0]) / 2;
    final midY = (eyeL[1] + eyeR[1]) / 2;
    final dx = eyeR[0] - eyeL[0];
    final dy = eyeR[1] - eyeL[1];
    final scale = math.sqrt(dx * dx + dy * dy);
    if (scale < 1.0) return null;
    final angle = math.atan2(dy, dx);
    final cosA = math.cos(-angle);
    final sinA = math.sin(-angle);

    List<double> norm(double px, double py) {
      final vx = (px - midX) / scale;
      final vy = (py - midY) / scale;
      return [vx * cosA - vy * sinA, vx * sinA + vy * cosA];
    }

    final fb = face.boundingBox;
    final fallback = norm(fb.center.dx, fb.center.dy);

    var missing = 0;
    final out = <double>[];
    for (final entry in _contourPlan.entries) {
      final c = face.contours[entry.key];
      if (c == null || c.points.length < 2) {
        missing++;
        for (var i = 0; i < entry.value; i++) {
          out.add(fallback[0]);
          out.add(fallback[1]);
        }
        continue;
      }
      final raw = c.points
          .map((p) => [p.x.toDouble(), p.y.toDouble()])
          .toList(growable: false);
      for (final p in _resample(raw, entry.value)) {
        final n = norm(p[0], p[1]);
        out.add(n[0]);
        out.add(n[1]);
      }
    }
    for (final t in _landmarkPlan) {
      final lp = face.landmarks[t]?.position;
      if (lp == null) {
        missing++;
        out.add(fallback[0]);
        out.add(fallback[1]);
      } else {
        final n = norm(lp.x.toDouble(), lp.y.toDouble());
        out.add(n[0]);
        out.add(n[1]);
      }
    }
    if (missing > _maxMissingFeatures) return null;
    return out;
  }

  List<double>? _eyePoint(
    Face face,
    FaceContourType contourType,
    FaceLandmarkType landmarkType,
  ) {
    final c = face.contours[contourType];
    if (c != null && c.points.isNotEmpty) {
      var sx = 0.0, sy = 0.0;
      for (final p in c.points) {
        sx += p.x.toDouble();
        sy += p.y.toDouble();
      }
      return [sx / c.points.length, sy / c.points.length];
    }
    final lp = face.landmarks[landmarkType]?.position;
    if (lp != null) return [lp.x.toDouble(), lp.y.toDouble()];
    return null;
  }

  List<List<double>> _resample(List<List<double>> poly, int n) {
    if (poly.length == 1) return List.generate(n, (_) => poly.first);
    final cum = <double>[0];
    for (var i = 1; i < poly.length; i++) {
      final ddx = poly[i][0] - poly[i - 1][0];
      final ddy = poly[i][1] - poly[i - 1][1];
      cum.add(cum.last + math.sqrt(ddx * ddx + ddy * ddy));
    }
    final total = cum.last;
    if (total < 1e-6) return List.generate(n, (_) => poly.first);
    final out = <List<double>>[];
    for (var k = 0; k < n; k++) {
      final target = total * k / (n - 1);
      var i = 1;
      while (i < cum.length - 1 && cum[i] < target) {
        i++;
      }
      final segLen = cum[i] - cum[i - 1];
      final t = segLen < 1e-9 ? 0.0 : (target - cum[i - 1]) / segLen;
      out.add([
        poly[i - 1][0] + (poly[i][0] - poly[i - 1][0]) * t,
        poly[i - 1][1] + (poly[i][1] - poly[i - 1][1]) * t,
      ]);
    }
    return out;
  }

  double distance(List<double> a, List<double> b) {
    if (a.isEmpty || a.length != b.length) return double.infinity;
    var s = 0.0;
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      s += d * d;
    }
    return math.sqrt(s / a.length);
  }

  double _maxPairwise(List<List<double>> v) {
    var m = 0.0;
    for (var i = 0; i < v.length; i++) {
      for (var j = i + 1; j < v.length; j++) {
        final d = distance(v[i], v[j]);
        if (d > m) m = d;
      }
    }
    return m;
  }

  /// Builds the template from [samples]: keeps only a mutually-consistent
  /// subset, averages it, and stores it along with its spread. Throws
  /// [StateError] if a tight-enough set of at least [minEnrollSamples]
  /// readings can't be found — the caller should ask the user to retry.
  Future<void> enroll(List<List<double>> samples) async {
    if (samples.isEmpty) throw StateError('No face readings captured.');
    final len = samples.first.length;
    final clean = samples.where((s) => s.length == len).toList();
    if (clean.length < minEnrollSamples) {
      throw StateError('Not enough clear face readings.');
    }

    var kept = List<List<double>>.from(clean);
    while (kept.length > minEnrollSamples &&
        _maxPairwise(kept) > enrollConsistency) {
      // drop the reading that is, on average, furthest from the rest
      var worstIdx = 0;
      var worstAvg = -1.0;
      for (var i = 0; i < kept.length; i++) {
        var sum = 0.0;
        for (var j = 0; j < kept.length; j++) {
          if (i == j) continue;
          sum += distance(kept[i], kept[j]);
        }
        final avg = sum / (kept.length - 1);
        if (avg > worstAvg) {
          worstAvg = avg;
          worstIdx = i;
        }
      }
      kept.removeAt(worstIdx);
    }

    final spread = _maxPairwise(kept);
    if (spread > enrollConsistency) {
      throw StateError('Face readings were too inconsistent.');
    }

    final avg = List<double>.filled(len, 0);
    for (final s in kept) {
      for (var i = 0; i < len; i++) {
        avg[i] += s[i];
      }
    }
    for (var i = 0; i < len; i++) {
      avg[i] /= kept.length;
    }
    await _store(avg, spread);
  }

  Future<void> _store(List<double> vector, double spread) async {
    // Layout: [spread, ...vector]
    final f64 = Float64List(vector.length + 1)
      ..[0] = spread
      ..setRange(1, vector.length + 1, vector);
    await _secure.write(
      key: _kTemplateKey,
      value: base64Encode(f64.buffer.asUint8List()),
    );
    for (final k in _kLegacyKeys) {
      try {
        await _secure.delete(key: k);
      } catch (_) {}
    }
  }

  Future<({double spread, List<double> vector})?> _loadTemplate() async {
    try {
      final raw = await _secure.read(key: _kTemplateKey);
      if (raw == null || raw.isEmpty) return null;
      final bytes = base64Decode(raw);
      if (bytes.lengthInBytes % 8 != 0 || bytes.lengthInBytes < 16) return null;
      final f64 = bytes.buffer
          .asFloat64List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 8);
      return (spread: f64[0], vector: f64.sublist(1).toList(growable: false));
    } catch (_) {
      return null;
    }
  }

  /// Returns whether [candidate] matches the enrolled template and the measured
  /// distance. The accept budget is `min(matchThreshold, enrollSpread + margin)`
  /// so a tight enrollment yields a stricter check.
  Future<({bool matched, double dist})> verifyVector(
    List<double> candidate,
  ) async {
    final tmpl = await _loadTemplate();
    if (tmpl == null || tmpl.vector.length != candidate.length) {
      return (matched: false, dist: double.infinity);
    }
    final d = distance(candidate, tmpl.vector);
    final budget =
        math.min(matchThreshold, tmpl.spread + _spreadMargin).clamp(0.02, matchThreshold);
    return (matched: d <= budget, dist: d);
  }
}
