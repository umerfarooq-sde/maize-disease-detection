import '../../core/exceptions/app_exception.dart';
import 'assistant_answer.dart';

class ReferenceMedia {
  ReferenceMedia(
    this.id,
    this.slug,
    this.altText,
    this.status,
    this.revision,
    this.order,
    this.path,
    this.source,
    this.license,
    this.credit,
    this.attribution,
    this.synthetic,
    this.rightsConfirmed,
  );
  final String id,
      slug,
      altText,
      status,
      revision,
      license,
      credit,
      attribution;
  final int order;
  final String? path;
  final AssistantSourceReference source;
  final bool synthetic, rightsConfirmed;
  factory ReferenceMedia.fromJson(Object? value) {
    const invalid = AppException(AppErrorKind.invalidResponse);
    if (value is! Map<String, dynamic>) throw invalid;
    String text(String key, int max) {
      final v = value[key];
      if (v is! String || v.isEmpty || v.length > max) throw invalid;
      return v;
    }

    final id = text('id', 36),
        revision = text('revision', 64),
        order = value['sortOrder'],
        path = value['imagePath'],
        p = value['provenance'];
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(revision) ||
        order is! int ||
        order < 0 ||
        order > 10000 ||
        p is! Map<String, dynamic> ||
        !['DRAFT', 'ACTIVE', 'INACTIVE'].contains(value['status']) ||
        (path != null &&
            path != 'disease-images/$id/image' &&
            path != 'admin/disease-images/$id/image') ||
        p['rightsConfirmed'] is! bool ||
        !['REFERENCE', 'SYNTHETIC_TEST'].contains(p['contentKind'])) {
      throw invalid;
    }
    String provenance(String key, int max) {
      final v = p[key];
      if (v is! String || v.trim().isEmpty || v.length > max) throw invalid;
      return v;
    }

    return ReferenceMedia(
      id,
      text('diseaseSlug', 120),
      text('altText', 255),
      text('status', 20),
      revision,
      order,
      path as String?,
      AssistantSourceReference.fromJson(p['source']),
      provenance('license', 1000),
      provenance('contributor', 255),
      provenance('attribution', 1000),
      p['contentKind'] == 'SYNTHETIC_TEST',
      p['rightsConfirmed'] as bool,
    );
  }
}
