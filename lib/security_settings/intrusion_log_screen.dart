import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/intrusion_service.dart';
import '../utils/liquid_colors.dart';
import '../utils/vault_crypto.dart';

class IntrusionLogScreen extends StatefulWidget {
  const IntrusionLogScreen({super.key});

  @override
  State<IntrusionLogScreen> createState() => _IntrusionLogScreenState();
}

class _IntrusionLogScreenState extends State<IntrusionLogScreen> {
  List<IntrusionEntry> _entries = [];
  bool _loading = true;
  final Map<int, String> _decryptedPaths = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    VaultCrypto.instance.wipeTempCache();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await IntrusionService.instance.getLog();
    if (!mounted) return;

    final paths = <int, String>{};
    for (final e in entries) {
      try {
        final temp = await VaultCrypto.instance.decryptToTemp(e.encryptedPath);
        paths[e.timestamp] = temp;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _decryptedPaths
        ..clear()
        ..addAll(paths);
      _loading = false;
    });
  }

  Future<void> _confirmDelete(IntrusionEntry entry) async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LiquidColors.backgroundLight,
        title: const Text('Delete capture?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This intrusion photo will be permanently removed.',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: LiquidColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await IntrusionService.instance.deleteEntry(entry);
    await _load();
  }

  Future<void> _confirmClearAll() async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LiquidColors.backgroundLight,
        title: const Text('Clear all captures?', style: TextStyle(color: Colors.white)),
        content: Text(
          'All ${_entries.length} intrusion photos will be permanently removed.',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: TextStyle(color: LiquidColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await IntrusionService.instance.clearAll();
    await _load();
  }

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year}  $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Intrusion Log',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: Icon(Icons.delete_sweep_rounded, color: LiquidColors.error),
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LiquidColors.backgroundGradient),
        child: _loading
            ? Center(child: CircularProgressIndicator(color: LiquidColors.accentBlue))
            : _entries.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) => _entryTile(_entries[i]),
                  ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: LiquidColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.verified_user_rounded,
                size: 50, color: LiquidColors.success),
          ),
          const SizedBox(height: 24),
          const Text(
            'No intrusion attempts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'When someone enters a wrong PIN with break-in detection enabled, their photo will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryTile(IntrusionEntry entry) {
    final path = _decryptedPaths[entry.timestamp];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: path == null ? null : () => _viewFull(path, entry),
          onLongPress: () => _confirmDelete(entry),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: path == null
                        ? Container(
                            color: LiquidColors.backgroundDeep,
                            child: Icon(Icons.broken_image_rounded,
                                color: Colors.grey.shade600, size: 32),
                          )
                        : Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: LiquidColors.backgroundDeep,
                              child: Icon(Icons.broken_image_rounded,
                                  color: Colors.grey.shade600, size: 32),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wrong PIN attempt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(entry.when),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: Colors.grey.shade500),
                  onPressed: () => _confirmDelete(entry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _viewFull(String path, IntrusionEntry entry) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            _formatDate(entry.when),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        body: Center(
          child: InteractiveViewer(child: Image.file(File(path))),
        ),
      ),
    ));
  }
}
