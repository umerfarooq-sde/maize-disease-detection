import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../knowledge/helpers.dart' as knowledge;
import '../assistant/helpers.dart' as assistant;
import '../admin/predeployment_test.dart' show mediaJson;
import '../auth/session_test.dart' show response;

Map<String, Object?> r04Detail([String slug = 'common-rust']) => {
  ...knowledge.summaryJson(slug),
  'sections': [
    {
      ...knowledge.sectionJson(),
      'title': 'UI fixture overview',
      'content':
          'Synthetic UI fixture, not agricultural guidance. Inspect reviewed source context before making field decisions.\n\nThis paragraph tests readable spacing and long scientific terminology.',
    },
    {
      ...knowledge.sectionJson(),
      'documentId': '22345678-1234-4123-8123-123456789abc',
      'documentKey': 'fixture-prevention',
      'documentVersion': 2,
      'knowledgeType': 'PREVENTION',
      'title': 'UI fixture prevention',
      'content':
          'Synthetic prevention passage for presentation tests only. No real recommendation is supplied.',
    },
  ],
};

Map<String, Object?> r04Media() => {
  ...mediaJson(),
  'diseaseSlug': 'common-rust',
  'altText': 'UI TEST · SYNTHETIC leaf shape, not disease evidence',
};

MockClient r04Client({List<int>? imageBytes, bool images = false}) =>
    MockClient((request) async {
      if (request.url.path.endsWith('/knowledge/ask')) {
        return response(assistant.answerJson());
      }
      if (request.url.path.endsWith('/images')) {
        return response({
          'items': images ? [r04Media()] : [],
        });
      }
      if (request.url.path.endsWith('/image')) {
        return http.Response.bytes(
          imageBytes!,
          200,
          headers: {'content-type': 'image/png'},
        );
      }
      if (request.url.path.endsWith('/diseases')) {
        return response({
          'items': knowledge.slugs.map(knowledge.summaryJson).toList(),
        });
      }
      return response(r04Detail(request.url.pathSegments.last));
    });

Future<List<int>> r04Image() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xffeff3ec), BlendMode.src);
  final leaf = Path()
    ..moveTo(150, 240)
    ..cubicTo(60, 180, 80, 80, 180, 20)
    ..cubicTo(230, 130, 220, 200, 150, 240)
    ..close();
  canvas.drawPath(leaf, Paint()..color = const Color(0xff287551));
  canvas.drawLine(
    const Offset(150, 240),
    const Offset(180, 40),
    Paint()
      ..color = const Color(0xffe4f09a)
      ..strokeWidth = 3,
  );
  final label = TextPainter(
    text: const TextSpan(
      text: 'UI TEST · SYNTHETIC',
      style: TextStyle(
        color: Color(0xff172b22),
        fontSize: 12,
        fontFamily: 'Plus Jakarta Sans',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, const Offset(12, 270));
  final picture = recorder.endRecording();
  final image = await picture.toImage(400, 300);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  label.dispose();
  return bytes!.buffer.asUint8List();
}

Future<void> settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate().toList()) {
      await precacheImage(
        (element.widget as Image).image,
        element,
        onError: (_, _) =>
            throw StateError('Synthetic UI fixture failed decoding'),
      );
    }
  });
  await tester.pumpAndSettle();
}
