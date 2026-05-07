import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

class SendFeedbackScreen extends StatefulWidget {
  const SendFeedbackScreen({super.key});

  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  static const _supportEmail = 'hello@farhatullah.com';
  static const _maxAttachmentBytes = 25 * 1024 * 1024;
  static const _maxAttachments = 8;

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final List<_Attachment> _attachments = [];

  String _category = 'General';
  bool _sending = false;

  static const _categories = <_FeedbackCategory>[
    _FeedbackCategory(
      key: 'Bug',
      label: 'Bug',
      icon: Icons.bug_report_outlined,
      color: Color(0xFFEF4444),
    ),
    _FeedbackCategory(
      key: 'Feature',
      label: 'Feature',
      icon: Icons.lightbulb_outline_rounded,
      color: Color(0xFFF59E0B),
    ),
    _FeedbackCategory(
      key: 'Praise',
      label: 'Praise',
      icon: Icons.favorite_outline_rounded,
      color: Color(0xFFEC4899),
    ),
    _FeedbackCategory(
      key: 'General',
      label: 'General',
      icon: Icons.chat_bubble_outline_rounded,
      color: Color(0xFF3B82F6),
    ),
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  int get _totalBytes =>
      _attachments.fold<int>(0, (sum, a) => sum + a.size);

  Future<void> _pickAttachments({required bool imagesOnly}) async {
    if (_attachments.length >= _maxAttachments) {
      FlushBarHelper.flushBarWarningMessage(
        'You can attach up to $_maxAttachments files.',
        context,
      );
      return;
    }

    HapticFeedback.selectionClick();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: imagesOnly ? FileType.image : FileType.any,
        allowMultiple: true,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;

      final newAttachments = <_Attachment>[];
      for (final f in result.files) {
        if (f.path == null) continue;
        final file = File(f.path!);
        final size = await file.length();
        newAttachments.add(_Attachment(
          file: file,
          name: f.name,
          size: size,
          isImage: imagesOnly || _looksLikeImage(f.name),
        ));
      }

      final wouldBeTotal = _totalBytes +
          newAttachments.fold<int>(0, (s, a) => s + a.size);
      if (wouldBeTotal > _maxAttachmentBytes) {
        if (!mounted) return;
        FlushBarHelper.flushBarErrorMessage(
          'Attachments exceed ${_formatBytes(_maxAttachmentBytes)}. Pick fewer or smaller files.',
          context,
        );
        return;
      }
      if (_attachments.length + newAttachments.length > _maxAttachments) {
        if (!mounted) return;
        FlushBarHelper.flushBarErrorMessage(
          'Total would exceed $_maxAttachments attachments.',
          context,
        );
        return;
      }

      setState(() => _attachments.addAll(newAttachments));
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage(
        'Could not attach: ${e.toString()}',
        context,
      );
    }
  }

  bool _looksLikeImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.bmp');
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    HapticFeedback.lightImpact();

    try {
      final subject = _subjectController.text.trim();
      final body = _messageController.text.trim();
      final hasAttachments = _attachments.isNotEmpty;
      final hasMailtoHandler = await _hasMailtoHandler();

      if (hasAttachments) {
        if (await _tryNativeEmail(subject, body)) {
          if (!mounted) return;
          await _showComposerOpenedSheet(carriedAttachments: true);
          return;
        }
        if (hasMailtoHandler && await _tryMailto(subject, body)) {
          if (!mounted) return;
          FlushBarHelper.flushBarWarningMessage(
            'Email app opened — attachments couldn\'t be carried over. '
            'Add them manually before tapping Send.',
            context,
          );
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) Navigator.of(context).pop();
          return;
        }
      } else {
        if (hasMailtoHandler && await _tryMailto(subject, body)) {
          if (!mounted) return;
          await _showComposerOpenedSheet(carriedAttachments: false);
          return;
        }
        if (await _tryNativeEmail(subject, body)) {
          if (!mounted) return;
          await _showComposerOpenedSheet(carriedAttachments: false);
          return;
        }
      }

      if (!mounted) return;
      await _showNoEmailAppSheet(subject: subject, body: body);
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage(
        'Failed to open email app: ${e.toString()}',
        context,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _hasMailtoHandler() async {
    try {
      final probe = Uri(scheme: 'mailto', path: _supportEmail);
      return await canLaunchUrl(probe);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryNativeEmail(String subject, String body) async {
    try {
      await FlutterEmailSender.send(Email(
        subject: subject,
        body: body,
        recipients: [_supportEmail],
        attachmentPaths: _attachments.map((a) => a.file.path).toList(),
        isHTML: false,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryMailto(String subject, String body) async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: _encodeQuery({'subject': subject, 'body': body}),
      );
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryGmailWeb(String subject, String body) async {
    try {
      final uri = Uri.https('mail.google.com', '/mail/', {
        'view': 'cm',
        'fs': '1',
        'to': _supportEmail,
        'su': subject,
        'body': body,
      });
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryGmailPlayStore() async {
    try {
      final uri = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.google.android.gm');
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyMessageToClipboard(String subject, String body) async {
    final text = StringBuffer()
      ..writeln('To: $_supportEmail')
      ..writeln('Subject: $subject')
      ..writeln()
      ..writeln(body);
    await Clipboard.setData(ClipboardData(text: text.toString()));
  }

  Future<void> _showNoEmailAppSheet({
    required String subject,
    required String body,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidColors.warning.withValues(alpha: 0.16),
                  border: Border.all(
                    color: LiquidColors.warning.withValues(alpha: 0.4),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  color: LiquidColors.warning,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'No email app found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This device doesn\'t have an email app set up. Pick a way to reach us:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _fallbackTile(
                    sheetContext,
                    icon: Icons.public_rounded,
                    color: LiquidColors.accentBlue,
                    title: 'Open Gmail in Browser',
                    subtitle: _attachments.isEmpty
                        ? 'Composes the message in web Gmail'
                        : 'Composes the message in web Gmail (attachments not carried over)',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final ok = await _tryGmailWeb(subject, body);
                      if (!mounted) return;
                      if (ok) {
                        FlushBarHelper.flushBarInfoMessage(
                          'Gmail opened in your browser. Tap Send there to deliver.',
                          context,
                        );
                        await Future.delayed(
                            const Duration(milliseconds: 600));
                        if (mounted) Navigator.of(context).pop();
                      } else {
                        FlushBarHelper.flushBarErrorMessage(
                          'Could not open a browser.',
                          context,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _fallbackTile(
                    sheetContext,
                    icon: Icons.copy_rounded,
                    color: LiquidColors.accentPurple,
                    title: 'Copy Message',
                    subtitle:
                        'Copies the full message to your clipboard so you can paste it anywhere',
                    onTap: () async {
                      await _copyMessageToClipboard(subject, body);
                      if (!mounted) return;
                      Navigator.of(sheetContext).pop();
                      FlushBarHelper.flushBarSuccessMessage(
                        'Copied. Paste it into any email or chat to $_supportEmail.',
                        context,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  if (Platform.isAndroid)
                    _fallbackTile(
                      sheetContext,
                      icon: Icons.download_rounded,
                      color: LiquidColors.success,
                      title: 'Install Gmail',
                      subtitle: 'Opens the Play Store',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _tryGmailPlayStore();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _fallbackTile(
    BuildContext sheetContext, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _showComposerOpenedSheet({
    required bool carriedAttachments,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.accentBlue.withValues(alpha: 0.4),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Almost there',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                carriedAttachments
                    ? 'Your message and attachments are loaded in your email app. '
                        'Tap Send there to deliver it to $_supportEmail.'
                    : 'Your message is loaded in your email app. '
                        'Tap Send there to deliver it to $_supportEmail.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    double size = bytes / 1024;
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor =
        _categories.firstWhere((c) => c.key == _category).color;
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final horizontalPadding =
        width < 360 ? 16.0 : (width < 600 ? 20.0 : 28.0);
    final keyboardInset = media.viewInsets.bottom;

    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.backgroundDeep,
                LiquidColors.backgroundMid,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.accentBlue.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Send Feedback',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
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
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                24 + keyboardInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _intro(),
                  const SizedBox(height: 24),
                  _label('What kind of feedback?'),
                  const SizedBox(height: 10),
                  _categoryGrid(),
                  const SizedBox(height: 24),
                  _label('Subject'),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _subjectController,
                    hint: 'A short summary of your feedback',
                    color: categoryColor,
                    minLines: 1,
                    maxLines: 1,
                    maxLength: 80,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a subject';
                      }
                      if (value.trim().length < 3) {
                        return 'Subject is too short';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _label('Message'),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _messageController,
                    hint:
                        'Describe what happened, what you expected, and any steps to reproduce.',
                    color: categoryColor,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: 2000,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a message';
                      }
                      if (value.trim().length < 10) {
                        return 'Message is too short';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  _attachmentsSection(categoryColor),
                  const SizedBox(height: 16),
                  _privacyNote(),
                  const SizedBox(height: 24),
                  _submitButton(categoryColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.accentBlue.withValues(alpha: 0.16),
            LiquidColors.accentPurple.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LiquidColors.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LiquidColors.accentBlue.withValues(alpha: 0.3),
                  LiquidColors.accentBlue.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Icon(
              Icons.forum_rounded,
              color: LiquidColors.accentBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'d love to hear from you',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tell us what\'s working, what\'s not, or what you wish the app could do.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade300,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((c) {
        final selected = c.key == _category;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _category = c.key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? c.color.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? c.color
                      : Colors.white.withValues(alpha: 0.08),
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: c.color.withValues(alpha: 0.32),
                          blurRadius: 14,
                          spreadRadius: -3,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    c.icon,
                    size: 16,
                    color: selected ? c.color : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey.shade300,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required Color color,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      cursorColor: color,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 13,
          height: 1.5,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        counterStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: LiquidColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: LiquidColors.error, width: 1.4),
        ),
        errorStyle: const TextStyle(color: LiquidColors.error, fontSize: 12),
      ),
    );
  }

  Widget _attachmentsSection(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('Attachments'),
            if (_attachments.isNotEmpty)
              Text(
                '${_attachments.length}/$_maxAttachments · ${_formatBytes(_totalBytes)}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _attachButton(
                icon: Icons.image_outlined,
                label: 'Add Screenshot',
                color: accent,
                onTap: () => _pickAttachments(imagesOnly: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _attachButton(
                icon: Icons.attach_file_rounded,
                label: 'Attach File',
                color: accent,
                onTap: () => _pickAttachments(imagesOnly: false),
              ),
            ),
          ],
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _attachments.length; i++) ...[
                  _attachmentRow(_attachments[i], i, accent),
                  if (i < _attachments.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _attachButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final disabled = _sending || _attachments.length >= _maxAttachments;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: disabled
                ? Colors.white.withValues(alpha: 0.02)
                : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: disabled
                  ? Colors.white.withValues(alpha: 0.06)
                  : color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: disabled ? Colors.grey.shade600 : color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled ? Colors.grey.shade600 : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentRow(_Attachment a, int index, Color accent) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: a.isImage
                  ? Image.file(
                      a.file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fileTypeBadge(a, accent),
                    )
                  : _fileTypeBadge(a, accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatBytes(a.size),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _sending
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    setState(() => _attachments.removeAt(index));
                  },
            icon: Icon(
              Icons.close_rounded,
              color: Colors.grey.shade400,
              size: 18,
            ),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _fileTypeBadge(_Attachment a, Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.16),
      alignment: Alignment.center,
      child: Icon(
        a.isImage
            ? Icons.image_rounded
            : Icons.insert_drive_file_rounded,
        color: accent,
        size: 22,
      ),
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 14,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your message is sent through your device\'s email app. '
              'Nothing leaves the device until you confirm there. '
              'No vault content is attached automatically.',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton(Color accent) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _sending ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          disabledBackgroundColor: accent.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_sending)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              _sending ? 'Sending…' : 'Send Feedback',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _FeedbackCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _Attachment {
  final File file;
  final String name;
  final int size;
  final bool isImage;

  const _Attachment({
    required this.file,
    required this.name,
    required this.size,
    required this.isImage,
  });
}
