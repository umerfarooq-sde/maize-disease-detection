import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/assistant_answer.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/ai_assistant/view_models/assistant_view_model.dart';
import '../assistant/helpers.dart';
import '../assistant/widget_test.dart' show page;
import '../assistant/widget_test.dart' show submit;
import '../scans/helpers.dart' show scanJson;
import '../scans/widget_test.dart' show tapVisible;
import '../support/design_fonts.dart';

void main() {
  setUpAll(loadDesignFonts);
  testWidgets('pinned composer fits a short large-text keyboard viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final scan = ScanRecord.fromJson(scanJson(status: ScanStatus.completed));
    final model = AssistantViewModel(
      FakeAssistantRepository()..hasAuthenticatedSession = true,
      initialScan: scan,
    );
    addTearDown(model.dispose);
    await model.explainScan(scan);
    model.selectDisease('Northern_Corn_Leaf_Blight');
    model.selectTopic('MANAGEMENT');
    await tester.pumpWidget(
      page(model, textScale: 2, viewInsets: const EdgeInsets.only(bottom: 180)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('assistant-send')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const Key('assistant-question')), 'ab');
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-input-error')), findsOneWidget);
    expect(
      find.byKey(const Key('assistant-send')).hitTestable(),
      findsOneWidget,
    );
    expect(model.turns, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'response follows only near bottom and jump-to-latest is explicit while reading',
    (tester) async {
      final repository = FakeAssistantRepository();
      final model = AssistantViewModel(repository);
      addTearDown(model.dispose);
      await model.ask('First fixture maize question');
      await tester.pumpWidget(page(model));
      await tester.pumpAndSettle();
      final pending = Completer<AssistantAnswer>();
      repository.responses.add(pending.future);
      await submit(tester, 'Second fixture maize question');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      final conversation = tester.widget<SingleChildScrollView>(
        find.byKey(const PageStorageKey('assistant-conversation')),
      );
      final controller = conversation.controller!;
      expect(controller.position.extentAfter, closeTo(0, 1));
      controller.jumpTo(0);
      await tester.pump();
      pending.complete(assistantAnswer());
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        0,
        reason: 'Do not move a reader to a new answer automatically',
      );
      expect(find.byKey(const Key('assistant-jump-latest')), findsOneWidget);
      await tester.tap(find.byKey(const Key('assistant-jump-latest')));
      await tester.pumpAndSettle();
      expect(controller.position.extentAfter, closeTo(0, 1));
      expect(find.byKey(const Key('assistant-jump-latest')), findsNothing);
      expect(repository.asks, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'copy retains attribution, citation jumps to exact source, clear can be cancelled',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repository = FakeAssistantRepository();
      final model = AssistantViewModel(repository);
      addTearDown(model.dispose);
      await model.ask('Fixture question about maize');
      await tester.pumpWidget(page(model));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Sources: e1'));
      expect(
        find.text('e1 · Reviewed maize reference').hitTestable(),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const Key('assistant-copy-answer')));
      expect(copied, contains('Synthetic reviewed test paragraph.'));
      expect(copied, contains('https://extension.example.test/maize'));
      expect(copied, contains('document v1'));
      await tester.enterText(
        find.byKey(const Key('assistant-question')),
        'Retain this draft',
      );
      await tester.tap(find.byKey(const Key('assistant-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(model.turns, hasLength(1));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('assistant-question')))
            .controller!
            .text,
        'Retain this draft',
      );
      expect(repository.asks, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rate-limited turn retains safe error and retries without duplicating turn',
    (tester) async {
      final repository = FakeAssistantRepository()
        ..responses.add(
          Future.error(const AppException(AppErrorKind.rateLimited)),
        );
      final model = AssistantViewModel(repository);
      addTearDown(model.dispose);
      await model.ask('Fixture maize symptoms question');
      await tester.pumpWidget(page(model));
      await tester.pumpAndSettle();
      expect(
        find.text(const AppException(AppErrorKind.rateLimited).message),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const Key('assistant-retry')));
      expect(model.turns, hasLength(1));
      expect(repository.asks, hasLength(2));
      expect(find.text('From reviewed knowledge'), findsOneWidget);
    },
  );
}
