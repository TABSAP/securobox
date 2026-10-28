import 'package:flutter/material.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/widgets/app_loader.dart';

class DecryptGate extends StatefulWidget {
  final String source;
  final bool encrypted;
  final int? encryptionVersion;
  final Widget Function(BuildContext context, String path) builder;

  const DecryptGate({
    super.key,
    required this.source,
    required this.encrypted,
    this.encryptionVersion,
    required this.builder,
  });

  @override
  State<DecryptGate> createState() => _DecryptGateState();
}

class _DecryptGateState extends State<DecryptGate> {
  String? _path;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (!widget.encrypted) {
      if (mounted) setState(() => _path = widget.source);
      return;
    }
    try {
      final decrypted = await VaultCrypto.instance.decryptToTemp(
        widget.source,
        formatVersion: widget.encryptionVersion,
      );
      if (mounted) setState(() => _path = decrypted);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path != null) return widget.builder(context, path);

    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: LiquidColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: _failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: LiquidColors.error,
                    size: 52,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Unable to open this file',
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const AppLoader(size: 34),
      ),
    );
  }
}
