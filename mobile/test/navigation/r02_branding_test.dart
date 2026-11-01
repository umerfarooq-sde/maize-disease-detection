import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resources = 'android/app/src/main/res';
  test(
    'original source mark, legacy raster densities and adaptive/themed icons exist',
    () {
      expect(
        File('assets/branding/maizedoctor-mark.svg').readAsStringSync(),
        contains('MAIZEDOCTOR maize and leaf mark'),
      );
      for (final density in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        final bytes = File(
          '$resources/mipmap-${density.key}/ic_launcher.png',
        ).readAsBytesSync();
        final header = ByteData.sublistView(bytes);
        expect(header.getUint32(16), density.value);
        expect(header.getUint32(20), density.value);
      }
      for (final version in [26, 33]) {
        final xml = File(
          '$resources/mipmap-anydpi-v$version/ic_launcher.xml',
        ).readAsStringSync();
        expect(xml, contains('<adaptive-icon'));
        expect(xml, contains('@drawable/brand_foreground'));
        if (version == 33) expect(xml, contains('<monochrome'));
      }
      expect(
        File('$resources/drawable/brand_foreground.xml').readAsStringSync(),
        contains('#E4F09A'),
      );
    },
  );

  test(
    'native light/dark launch uses branding, without artificial delay or package changes',
    () {
      for (final folder in [
        'values',
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        final xml = File('$resources/$folder/styles.xml').readAsStringSync();
        expect(xml, contains('@drawable/launch_background'));
        if (folder.endsWith('v31')) {
          expect(xml, contains('android:windowSplashScreenAnimatedIcon'));
        }
        expect(xml, isNot(contains('windowSplashScreenAnimationDuration')));
      }
      expect(
        File('$resources/values/colors.xml').readAsStringSync(),
        contains('#F7F8F3'),
      );
      expect(
        File('$resources/values-night/colors.xml').readAsStringSync(),
        contains('#101A15'),
      );
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('applicationId = "com.maizedoctor.maizedoctor"'));
    },
  );
}
