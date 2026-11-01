import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Register lazily: startup never waits for license asset I/O.
void registerAppFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString(
      'assets/fonts/plus_jakarta_sans/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], notice);
  });
}
