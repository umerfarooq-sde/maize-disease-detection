import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/features/admin/widgets/specification_array_editor.dart';
import 'package:maizedoctor/features/admin/widgets/specification_rows.dart';
import 'package:maizedoctor/features/admin/widgets/calculator_editor_sections.dart';
import 'package:maizedoctor/features/admin/widgets/management_fields.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';
import 'r06b_content_test.dart' show r06bEnter;
import 'r06c_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'Advanced and structured adapters retain the original 12000-character JSON limit',
    (tester) async {
      final controller = TextEditingController(
        text: jsonEncode([
          {
            'key': 'x',
            'unit': 'KG',
            'description': 'test',
            'future': 'x' * 12000,
          },
        ]),
      );
      addTearDown(controller.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: form,
                child: SpecificationArrayEditor(
                  name: 'inputs',
                  controller: controller,
                  busy: false,
                  validator: (value) =>
                      validateSpecificationRows(value!, coefficients: false),
                ),
              ),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(
        find.text('Specification JSON may contain at most 12000 characters.'),
        findsOneWidget,
      );
      expect(controller.text.length, greaterThan(12000));
    },
  );
  test(
    'all original calculator fields occur exactly once in grouped presentation',
    () {
      for (final area in ManagementArea.values.where(isCalculatorManagement)) {
        final editor = ManagementEditor(area, null, {});
        final fields = managementFields(editor), seen = <String>[];
        calculatorEditorSections(editor, fields, (field) {
          seen.add(field.key);
          return const SizedBox();
        });
        expect(seen, fields.map((field) => field.key));
        expect(seen.toSet().length, fields.length);
      }
    },
  );
  test(
    'known input/output/coefficient JSON round trips without numeric coercion',
    () {
      final spec = r06cSpec();
      for (final key in ['inputs', 'outputs', 'coefficients']) {
        final raw = jsonEncode(spec[key]);
        final rows = structuredSpecificationRows(
          raw,
          coefficients: key == 'coefficients',
        );
        expect(jsonDecode(jsonEncode(rows)), jsonDecode(raw));
        expect(
          validateSpecificationRows(raw, coefficients: key == 'coefficients'),
          isNull,
        );
      }
      expect(
        (spec['coefficients'] as List).single['value'],
        '-0.000000000000000000123400',
      );
    },
  );
  for (final raw in [
    '{}',
    '[',
    '[]',
    '[{"key":"x","unit":"KG","description":""}]',
    '[{"key":"x","unit":"INVALID","description":"test"}]',
    '[{"key":"x","unit":"KG","description":"test"},{"key":"x","unit":"KG","description":"test"}]',
  ]) {
    test(
      'invalid definitions rejected: $raw',
      () => expect(
        validateSpecificationRows(raw, coefficients: false),
        isNotNull,
      ),
    );
  }
  test(
    'coefficient constraints, row bounds and required output keys match admission contract',
    () {
      for (final value in [1.25, '1e3', '+1', '01.5', 'NaN', '1' * 65]) {
        expect(
          validateSpecificationRows(
            jsonEncode([
              {
                'key': 'a',
                'unit': 'KG',
                'value': value,
                'sourceSection': 'test',
              },
            ]),
            coefficients: true,
          ),
          isNotNull,
        );
      }
      expect(
        validateSpecificationRows(
          jsonEncode([for (var i = 0; i < 17; i++) r06cVariable('x$i')]),
          coefficients: false,
        ),
        isNotNull,
      );
      expect(
        validateSpecificationRows(
          jsonEncode([r06cVariable('expected')]),
          coefficients: false,
          requiredOutputs: ['minimum', 'expected', 'potential'],
        ),
        isNotNull,
      );
      expect(validateSpecificationRows('[]', coefficients: true), isNull);
    },
  );
  testWidgets(
    'unknown fields stay in Advanced JSON byte-for-byte without a lossy structured switch',
    (tester) async {
      const raw =
          '[ {"key":"area","unit":"KG","description":"test","future":{"precision":"9007199254740993.0000001"}} ]';
      final controller = TextEditingController(text: raw);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpecificationArrayEditor(
                name: 'inputs',
                controller: controller,
                busy: false,
                validator: (value) =>
                    validateSpecificationRows(value!, coefficients: false),
              ),
            ),
          ),
        ),
      );
      expect(controller.text, raw);
      expect(
        find.textContaining('cannot be represented losslessly'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Structured inputs'),
            )
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('management-inputs')), findsOneWidget);
    },
  );
  testWidgets(
    'structured edits, advanced toggling and add/remove preserve coefficient decimal strings',
    (tester) async {
      final fixture = R06CFixture();
      await fixture.mount(
        tester,
        location: '/admin/manage?area=modelSpecifications',
      );
      await r06Tap(tester, find.text('New version from this'));
      expect(
        find.textContaining('Pending domain approval / Disabled'),
        findsOneWidget,
      );
      await r06bEnter(
        tester,
        'spec-coefficients-0-value',
        '-12345678901234567890.0000012300',
      );
      await r06Tap(tester, find.text('Advanced JSON · coefficients'));
      final raw = tester
          .widget<TextFormField>(
            find.byKey(const Key('management-coefficients')),
          )
          .controller!
          .text;
      expect(
        (jsonDecode(raw) as List).single['value'],
        '-12345678901234567890.0000012300',
      );
      await r06Tap(tester, find.text('Structured coefficients'));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('spec-coefficients-0-value')),
            )
            .controller!
            .text,
        '-12345678901234567890.0000012300',
      );
      await r06Tap(tester, find.text('Add coefficient'));
      expect(
        find.byKey(const Key('spec-coefficients-1-value')),
        findsOneWidget,
      );
      await r06Tap(tester, find.text('Remove coefficients definition 2'));
      expect(find.byKey(const Key('spec-coefficients-1-value')), findsNothing);
      await r06bEnter(
        tester,
        'management-reviewNote',
        'Synthetic source review for isolated specification test.',
      );
      await r06Tap(tester, find.byType(CheckboxListTile));
      await r06Tap(tester, find.text('Save draft'));
      final body = jsonDecode(fixture.writes.single.body) as Map;
      expect(
        (body['coefficients'] as List).single['value'],
        '-12345678901234567890.0000012300',
      );
      expect(body['expectedVersion'], 1);
      expect(body.containsKey('execution'), isFalse);
      expect(find.text('Activate'), findsNothing);
    },
  );
  testWidgets(
    'malformed advanced JSON blocks save with useful inline feedback',
    (tester) async {
      final fixture = R06CFixture();
      await fixture.mount(
        tester,
        location: '/admin/manage?area=modelSpecifications',
      );
      await r06Tap(tester, find.text('New version from this'));
      await r06Tap(tester, find.text('Advanced JSON · inputs'));
      await r06bEnter(tester, 'management-inputs', '{broken');
      await r06Tap(tester, find.text('Save draft'));
      expect(find.text('Enter a valid JSON array.'), findsOneWidget);
      expect(fixture.writes, isEmpty);
    },
  );
}
