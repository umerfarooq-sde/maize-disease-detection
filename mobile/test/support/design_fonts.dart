import 'dart:convert';
import 'package:flutter/services.dart';

/// Use the actual bundled faces, not Ahem or a network-loaded replacement.
Future<void> loadDesignFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final name in ['Plus Jakarta Sans', 'MaterialIcons']) {
    final family = manifest.cast<Map<String, dynamic>>().singleWhere(
      (item) => item['family'] == name,
    );
    final loader = FontLoader(name);
    final assets = (family['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((face) => face['asset'] as String)
        .toSet();
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
