import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/features/admin/widgets/admin_content_management.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/models/selected_leaf_image.dart';
import '../admin/management_test.dart' show managementDocument, managementId;
import '../admin/predeployment_test.dart' show mediaJson;
import '../auth/session_test.dart' show response;
import 'r06a_fixtures.dart';

const r06bLabels = [
  'Common_Rust',
  'Gray_Leaf_Spot',
  'Healthy',
  'Northern_Corn_Leaf_Blight',
];

Future<void> r06bEditDisease(WidgetTester tester, String label) async {
  final identity = find.text('Classifier context · $label');
  await r06Reveal(tester, identity);
  final record = find.ancestor(
    of: identity,
    matching: find.byType(AdminContentEntryCard),
  );
  await r06Tap(
    tester,
    find.descendant(of: record, matching: find.text('Edit display metadata')),
  );
}

Map<String, dynamic> r06bDisease(int index) => {
  'id': '00000000-0000-4000-8000-00000000000${index + 1}',
  'name': r06bLabels[index].replaceAll('_', ' '),
  'literalLabel': r06bLabels[index],
  'slug': r06bLabels[index].toLowerCase().replaceAll('_', '-'),
  'scientificName': null,
  'description':
      'Synthetic display metadata only. No agricultural facts supplied.',
  'status': 'ACTIVE',
  'revision': 'a' * 64,
  'catalogueMetadata': {
    'growthStages': <String>[],
    'severityDescriptors': <String>[],
  },
};

/// Entirely in-memory contracts. No source content, accounts or assets are changed.
class R06BFixture extends R06Fixture {
  final diseases = [for (var i = 0; i < 4; i++) r06bDisease(i)];
  final documents = [managementDocument()..['indexed'] = false];
  final media = <Map<String, Object?>>[];
  List<int>? image;
  int mutationStatus = 200, listStatus = 200, imageStatus = 200;
  bool more = false;
  Completer<void>? mutationGate;
  final writes = <http.Request>[];
  Map<String, dynamic>? uploaded;
  @override
  http.Client client() {
    final fallback = super.client();
    return MockClient((request) async {
      final path = request.url.path;
      if (!path.contains('/admin/knowledge/') &&
          !path.contains('/admin/disease-images')) {
        final copy = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        return fallback.send(copy).then(http.Response.fromStream);
      }
      requests.add(request);
      expect(request.headers['authorization'], 'Bearer admin.access.token');
      if (request.method != 'GET') {
        writes.add(request);
        await mutationGate?.future;
        if (mutationStatus != 200) {
          return response(null, status: mutationStatus);
        }
        if (path.endsWith('/disease-images')) {
          final text = utf8.decode(request.bodyBytes, allowMalformed: true);
          final raw = RegExp(
            'name="metadata"\\r\\n\\r\\n([^\\r]+)',
          ).firstMatch(text)!.group(1)!;
          uploaded = jsonDecode(raw) as Map<String, dynamic>;
          media.add({
            ...mediaJson(),
            ...uploaded!,
            'id': '22345678-1234-4123-8123-123456789abc',
            'status': 'DRAFT',
            'imagePath':
                'admin/disease-images/22345678-1234-4123-8123-123456789abc/image',
          });
        } else if (path.endsWith('/index')) {
          documents.first['indexed'] = true;
        } else if (path.contains('/documents/') && path.endsWith('/status')) {
          documents.first['status'] =
              (jsonDecode(request.body) as Map)['status'];
        } else if (path.endsWith('/documents')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          documents[0] = {
            ...managementDocument(),
            ...body,
            'version': (body['expectedVersion'] as int) + 1,
            'status': 'DRAFT',
            'indexed': false,
          };
        } else if (path.contains('/disease-images/')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (path.endsWith('/status')) {
            if (body['status'] == 'DELETED') {
              media.clear();
            } else {
              media.first['status'] = body['status'];
            }
          } else {
            media[0] = {...media.first, ...body, 'revision': 'b' * 64};
          }
        }
        return response(null);
      }
      if (listStatus != 200) return response(null, status: listStatus);
      if (path.endsWith('/image')) {
        return http.Response.bytes(
          image ?? [],
          imageStatus,
          headers: {'content-type': 'image/png'},
        );
      }
      if (path.endsWith('/items')) return response({'items': media});
      if (path.endsWith('/diseases')) {
        return response({'items': diseases, 'nextCursor': null});
      }
      if (path.endsWith('/documents')) {
        return response({
          'items': request.url.queryParameters.containsKey('cursor')
              ? [
                  {
                    ...managementDocument(status: 'ARCHIVED', version: 0),
                    'id': '00000000-0000-4000-8000-000000000009',
                  },
                ]
              : documents,
          'nextCursor':
              more && !request.url.queryParameters.containsKey('cursor')
              ? managementId
              : null,
        });
      }
      return response(documents.first);
    });
  }

  void addMedia() => media.add({
    ...mediaJson(),
    'diseaseSlug': 'common-rust',
    'status': 'DRAFT',
    'imagePath':
        'admin/disease-images/12345678-1234-4123-8123-123456789abc/image',
  });
}

class R06BPicker implements LeafImageDatasource {
  R06BPicker(this.image);
  final SelectedLeafImage? image;
  @override
  bool get cameraSupported => false;
  @override
  Future<SelectedLeafImage?> pick(LeafImageSource source) async => image;
  @override
  Future<SelectedLeafImage?> recover() async => null;
}
