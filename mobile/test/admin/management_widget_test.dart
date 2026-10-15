import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import 'package:maizedoctor/features/admin/view_models/admin_management_view_model.dart';
import 'package:maizedoctor/features/admin/views/admin_management_view.dart';
import 'package:maizedoctor/features/admin/widgets/management_editor_form.dart';
import 'management_test.dart';

void main() {
  testWidgets(
    'knowledge management shows fixed-class warning and activation requires confirmation',
    (tester) async {
      final repository = MemoryManagementRepository();
      final view = AdminManagementViewModel(repository);
      addTearDown(view.dispose);
      await view.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: view,
              child: const AdminManagementView(),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Classifier class mappings are read-only'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Activate'));
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();
      expect(find.text('Activate reviewed version?'), findsOneWidget);
      expect(repository.calls, isNot(contains('status:ACTIVE')));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.calls, isNot(contains('status:ACTIVE')));
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repository.calls, contains('status:ACTIVE'));
    },
  );
  testWidgets(
    'new knowledge form validates required source and fresh review without making requests',
    (tester) async {
      final editor = ManagementEditor(
        ManagementArea.knowledge,
        null,
        managementEditorValues(ManagementArea.knowledge, null),
      );
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManagementEditorForm(
                editor: editor,
                busy: false,
                onSave: (_) async {
                  calls++;
                },
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Save draft'));
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(
        find.text('Review and approve the source before saving.'),
        findsOneWidget,
      );
      expect(find.text('This field is required.'), findsWidgets);
    },
  );
  testWidgets(
    'source authoring remains scrollable at 320px, 200% text and keyboard insets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entry = knowledgeEntry();
      final editor = ManagementEditor(
        ManagementArea.knowledge,
        entry,
        managementEditorValues(ManagementArea.knowledge, entry),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 220),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ManagementEditorForm(
                    editor: editor,
                    busy: false,
                    onSave: (_) async {},
                    onCancel: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save draft'));
      expect(tester.takeException(), isNull);
    },
  );
}
