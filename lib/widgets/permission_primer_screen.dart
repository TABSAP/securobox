import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:video_player_app/utils/liquid_colors.dart';

/// A pre-permission "priming" screen, shown *before* any Android/iOS system
/// permission dialog so the user understands why access is being asked for.
///
/// Tapping **Continue** runs [onRequest] — the actual system permission
/// request — and the screen pops with the boolean result. This keeps the OS
/// dialog from appearing out of context, and lets a denial be handled as a
/// quiet, non-blocking outcome rather than a surprise.
///
/// Use [PermissionPrimerScreen.show]; the default [onRequest] asks for
/// storage / media access, which is what file handling needs.
class PermissionPrimerScreen extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<String> assurances;
  final Future<bool> Function() onRequest;

  const PermissionPrimerScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.assurances,
    required this.onRequest,
  });

  /// Pushes the primer and resolves to whether access was granted.
  static Future<bool> show(
    BuildContext context, {
    IconData icon = Icons.perm_media_rounded,
    String title = 'Allow access to your files',
    String message =
        'SecuroBox needs permission to read your photos, videos and '
        'documents so it can copy them into your encrypted vault.',
    List<String> assurances = const [
      'Files are encrypted on this device with AES-256',
      'Nothing is ever uploaded, shared or tracked',
      'Access is used only to move files into your vault',
    ],
    Future<bool> Function()? onRequest,
  }) async {
    final granted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PermissionPrimerScreen(
          icon: icon,
          title: title,
          message: message,
          assurances: assurances,
          onRequest: onRequest ?? requestMediaAccess,
        ),
      ),
    );
    return granted ?? false;
  }

  /// Default request — storage / media access. Android 13+ exposes granular
  /// media permissions; older Androids use a single storage permission.
  /// Requesting the set lets the platform resolve whichever it actually uses.
  static Future<bool> requestMediaAccess() async {
    try {
      final statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
        Permission.storage,
      ].request();
      return statuses.values.any((s) => s.isGranted || s.isLimited);
    } catch (_) {
      return false;
    }
  }

  @override
  State<PermissionPrimerScreen> createState() => _PermissionPrimerScreenState();
}

class _PermissionPrimerScreenState extends State<PermissionPrimerScreen> {
  bool _requesting = false;

  Future<void> _continue() async {
    if (_requesting) return;
    HapticFeedback.selectionClick();
    setState(() => _requesting = true);
    bool granted = false;
    try {
      granted = await widget.onRequest();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    Navigator.of(context).pop(granted);
  }

  void _notNow() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundMid,
              LiquidColors.backgroundLight,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LiquidColors.primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.primaryStart.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: -4,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 30),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: LiquidColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: LiquidColors.textSecondary,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),
                ...widget.assurances.map(_assuranceRow),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _requesting ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      backgroundColor: LiquidColors.accentBlue,
                      disabledBackgroundColor:
                          LiquidColors.accentBlue.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _requesting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _requesting ? null : _notNow,
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      color: LiquidColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _assuranceRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: LiquidColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.check_rounded,
              color: LiquidColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: LiquidColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
