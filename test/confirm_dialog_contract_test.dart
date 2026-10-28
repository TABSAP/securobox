import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_app/widgets/app_confirm_dialog.dart';

void main() {
  Future<void> pump(WidgetTester t, Widget child) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets(
    'OLD (buggy) pattern: onConfirm pops again -> showDialog yields null',
    (tester) async {
      bool? result;
      await pump(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: ctx,
                builder: (dctx) => AppConfirmDialog(
                  icon: Icons.lock_open_rounded,
                  accent: Colors.indigo,
                  title: 't',
                  message: 'm',
                  confirmLabel: 'Go',
                  onConfirm: () => Navigator.of(dctx).pop(true),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(
        result,
        isNull,
        reason: 'dialog already popped; the extra pop loses the value',
      );
    },
  );

  testWidgets('NEW (fixed) pattern: flag captured -> confirm observed', (
    tester,
  ) async {
    var confirmed = false;
    await pump(
      tester,
      Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () async {
            await showDialog<void>(
              context: ctx,
              builder: (_) => AppConfirmDialog(
                icon: Icons.lock_open_rounded,
                accent: Colors.indigo,
                title: 't',
                message: 'm',
                confirmLabel: 'Go',
                onConfirm: () => confirmed = true,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('cancel leaves flag false', (tester) async {
    var confirmed = false;
    await pump(
      tester,
      Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () async {
            await showDialog<void>(
              context: ctx,
              builder: (_) => AppConfirmDialog(
                icon: Icons.lock_open_rounded,
                accent: Colors.indigo,
                title: 't',
                message: 'm',
                confirmLabel: 'Go',
                onConfirm: () => confirmed = true,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
  });

  testWidgets(
    'renders Unlock & Restore with single-line maxLines and confirms',
    (tester) async {
      var confirmed = false;
      await pump(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              await showDialog<void>(
                context: ctx,
                builder: (_) => AppConfirmDialog(
                  icon: Icons.lock_open_rounded,
                  accent: Colors.indigo,
                  title: 'Unlock this file?',
                  message: 'File will be restored.',
                  confirmLabel: 'Unlock & Restore',
                  onConfirm: () => confirmed = true,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Unlock & Restore'));
      expect(textWidget.maxLines, 1);

      await tester.tap(find.text('Unlock & Restore'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    },
  );
}
