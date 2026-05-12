import 'dart:io';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:video_player_app/utils/liquid_circular_progress.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const AudioPlayerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late ja.AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  bool _isLooping = false;
  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double _currentSpeed = 1.0;
  double? _dragValue;

  late final AnimationController _disc = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudioPlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disc.dispose();
    _pulse.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _audioPlayer.pause();
    }
  }

  void _syncAnimations() {
    if (_isPlaying) {
      if (!_disc.isAnimating) _disc.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _disc.stop();
      _pulse.stop();
    }
  }

  Future<void> _initAudioPlayer() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      _audioPlayer = ja.AudioPlayer();

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      await _audioPlayer.setFilePath(widget.filePath);
      await _audioPlayer.setVolume(_volume);

      _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          _isLoading = state.processingState == ja.ProcessingState.loading ||
              state.processingState == ja.ProcessingState.buffering;
        });
        _syncAnimations();
      });

      _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      });

      _audioPlayer.positionStream.listen((position) {
        if (mounted && _dragValue == null) {
          setState(() => _position = position);
        }
      });

      _audioPlayer.playbackEventStream.listen(
        (event) {
          if (event.processingState == ja.ProcessingState.completed) {
            if (!mounted) return;
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
            _syncAnimations();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        },
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _play() async => _audioPlayer.play();
  Future<void> _pause() async => _audioPlayer.pause();

  Future<void> _stop() async {
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
    if (mounted) setState(() => _position = Duration.zero);
    _syncAnimations();
  }

  Future<void> _seek(Duration position) async {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > _duration ? _duration : position);
    await _audioPlayer.seek(clamped);
    if (mounted) setState(() => _position = clamped);
  }

  Future<void> _changeSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
    if (mounted) setState(() => _currentSpeed = speed);
  }

  Future<void> _toggleLoop() async {
    await _audioPlayer.setLoopMode(
      _isLooping ? ja.LoopMode.off : ja.LoopMode.one,
    );
    if (mounted) setState(() => _isLooping = !_isLooping);
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: LiquidColors.textPrimary),
        ),
        title: Text(
          'Audio Player',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LiquidColors.accentBlue.withValues(alpha: 0.12),
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundDeep,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError) return _errorState();
    if (_isLoading && _duration == Duration.zero) return _loadingState();

    final total = _duration.inMilliseconds.toDouble();
    final pos = _dragValue ??
        (total <= 0
            ? 0.0
            : _position.inMilliseconds.toDouble().clamp(0.0, total));

    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _disc1(),
                  const SizedBox(height: 30),
                  _nowPlayingLabel(),
                  const SizedBox(height: 10),
                  Text(
                    widget.fileName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _progress(pos, total),
                  const SizedBox(height: 22),
                  _mainTransport(),
                  const SizedBox(height: 20),
                  _pillRow(),
                  const SizedBox(height: 20),
                  _volumeRow(),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _stop,
                    icon: Icon(Icons.stop_rounded,
                        size: 18, color: LiquidColors.error),
                    label: Text('Stop',
                        style: TextStyle(
                            color: LiquidColors.error,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── spinning vinyl disc ──────────────────────────────────────────────────

  Widget _disc1() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final p = _isPlaying ? _pulse.value : 0.0;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    LiquidColors.accentBlue.withValues(alpha: 0.22 + 0.16 * p),
                blurRadius: 26 + 20 * p,
                spreadRadius: 2 + 6 * p,
              ),
            ],
          ),
          child: child,
        );
      },
      child: RotationTransition(
        turns: _disc,
        child: Container(
          width: 230,
          height: 230,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                LiquidColors.accentBlue,
                LiquidColors.accentPurple,
              ],
              center: const Alignment(-0.3, -0.4),
              radius: 1.1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final r in const [206.0, 178.0, 150.0, 122.0])
                Container(
                  width: r,
                  height: r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.10),
                      width: 1.4,
                    ),
                  ),
                ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidColors.surface,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isPlaying
                      ? Icons.music_note_rounded
                      : Icons.music_off_rounded,
                  color: LiquidColors.accentBlue,
                  size: 38,
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidColors.backgroundDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nowPlayingLabel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 14,
          child: _Equalizer(controller: _pulse, active: _isPlaying),
        ),
        const SizedBox(width: 8),
        Text(
          _isPlaying ? 'NOW PLAYING' : 'PAUSED',
          style: TextStyle(
            color: LiquidColors.accentBlue,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  // ── progress ─────────────────────────────────────────────────────────────

  Widget _progress(double pos, double total) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: LiquidColors.accentBlue,
            inactiveTrackColor:
                LiquidColors.textTertiary.withValues(alpha: 0.22),
            thumbColor: LiquidColors.accentBlue,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            overlayColor: LiquidColors.accentBlue.withValues(alpha: 0.18),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            min: 0,
            max: total <= 0 ? 1 : total,
            value: total <= 0 ? 0 : pos.clamp(0.0, total),
            onChanged:
                total <= 0 ? null : (v) => setState(() => _dragValue = v),
            onChangeEnd: total <= 0
                ? null
                : (v) {
                    _dragValue = null;
                    _seek(Duration(milliseconds: v.toInt()));
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(Duration(milliseconds: pos.toInt())),
                style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                _fmt(_duration),
                style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── transport ────────────────────────────────────────────────────────────

  Widget _mainTransport() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ghostBtn(
          icon: Icons.replay_10_rounded,
          onTap: () => _seek(_position - const Duration(seconds: 10)),
        ),
        const SizedBox(width: 26),
        _PlayButton(
          isPlaying: _isPlaying,
          isLoading: _isLoading,
          onTap: () => _isPlaying ? _pause() : _play(),
        ),
        const SizedBox(width: 26),
        _ghostBtn(
          icon: Icons.forward_10_rounded,
          onTap: () => _seek(_position + const Duration(seconds: 10)),
        ),
      ],
    );
  }

  Widget _ghostBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LiquidColors.surfaceMuted,
            border: Border.all(color: LiquidColors.cardBorder),
          ),
          child: Icon(icon, color: LiquidColors.textPrimary, size: 26),
        ),
      ),
    );
  }

  Widget _pillRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pill(
          icon: _isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
          label: _isLooping ? 'Loop on' : 'Loop',
          active: _isLooping,
          onTap: _toggleLoop,
        ),
        const SizedBox(width: 12),
        PopupMenuButton<double>(
          onSelected: _changeSpeed,
          tooltip: 'Playback speed',
          position: PopupMenuPosition.under,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (context) => _speedOptions.map((s) {
            final sel = s == _currentSpeed;
            return PopupMenuItem<double>(
              value: s,
              child: Row(
                children: [
                  Icon(Icons.speed_rounded,
                      size: 18,
                      color: sel
                          ? LiquidColors.accentBlue
                          : LiquidColors.textSecondary),
                  const SizedBox(width: 12),
                  Text('${s}x',
                      style: TextStyle(
                          color: sel
                              ? LiquidColors.accentBlue
                              : LiquidColors.textPrimary,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500)),
                  if (sel) ...[
                    const Spacer(),
                    Icon(Icons.check_rounded,
                        size: 18, color: LiquidColors.accentBlue),
                  ],
                ],
              ),
            );
          }).toList(),
          child: _pill(
            icon: Icons.speed_rounded,
            label: '${_currentSpeed}x',
            active: _currentSpeed != 1.0,
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required bool active,
    VoidCallback? onTap,
  }) {
    final c = active ? LiquidColors.accentBlue : LiquidColors.textSecondary;
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? LiquidColors.accentBlue.withValues(alpha: 0.14)
            : LiquidColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? LiquidColors.accentBlue.withValues(alpha: 0.45)
              : LiquidColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: c, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: body,
      ),
    );
  }

  Widget _volumeRow() {
    return Row(
      children: [
        Icon(
          _volume <= 0.001
              ? Icons.volume_off_rounded
              : _volume < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
          color: LiquidColors.textTertiary,
          size: 20,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: LiquidColors.accentBlue.withValues(alpha: 0.8),
              inactiveTrackColor:
                  LiquidColors.textTertiary.withValues(alpha: 0.22),
              thumbColor: LiquidColors.accentBlue,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor: LiquidColors.accentBlue.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: _volume,
              onChanged: (v) {
                setState(() => _volume = v);
                _audioPlayer.setVolume(v);
              },
            ),
          ),
        ),
        Icon(Icons.volume_up_rounded,
            color: LiquidColors.textTertiary, size: 20),
      ],
    );
  }

  // ── states ───────────────────────────────────────────────────────────────

  Widget _loadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LiquidCircularProgress(size: 80),
          const SizedBox(height: 20),
          Text('Loading audio…',
              style:
                  TextStyle(color: LiquidColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiquidColors.error.withValues(alpha: 0.14),
                border: Border.all(
                    color: LiquidColors.error.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.error_outline_rounded,
                  color: LiquidColors.error, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Couldn\'t play this audio',
                style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'The file may be missing, corrupted, or in an unsupported format.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: LiquidColors.textSecondary,
                  fontSize: 13,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _initAudioPlayer();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LiquidColors.accentBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;
  const _PlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: LiquidColors.accentBlue.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.6, color: Colors.white),
                )
              : Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
        ),
      ),
    );
  }
}

class _Equalizer extends StatelessWidget {
  final AnimationController controller;
  final bool active;
  const _Equalizer({required this.controller, required this.active});

  @override
  Widget build(BuildContext context) {
    const phases = [0.0, 1.7, 3.1, 4.6];
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final h = active
                ? 4 + 9 * (0.5 + 0.5 * math.sin(t * math.pi * 2 + phases[i]))
                : 3.0;
            return Container(
              width: 3,
              height: h.toDouble(),
              decoration: BoxDecoration(
                color: LiquidColors.accentBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
