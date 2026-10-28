// SDK/OS essentials only. Never inherit server credentials or environment hooks.
const tooling = new Set([
  'PATH',
  'PATHEXT',
  'SYSTEMROOT',
  'WINDIR',
  'PROGRAMFILES',
  'PROGRAMFILES(X86)',
  'PROGRAMW6432',
  'COMSPEC',
  'USERPROFILE',
  'APPDATA',
  'LOCALAPPDATA',
  'TEMP',
  'TMP',
  'HOME',
  'PUB_CACHE',
  'FLUTTER_ROOT',
  'ANDROID_HOME',
  'ANDROID_SDK_ROOT',
  'JAVA_HOME',
  'CI',
  'TERM',
  'NO_COLOR',
  'FLUTTER_SUPPRESS_ANALYTICS',
  'DART_SUPPRESS_ANALYTICS',
]);

export function flutterTestEnvironment(source = process.env) {
  return Object.fromEntries(
    Object.entries(source).filter(
      ([key, value]) => tooling.has(key.toUpperCase()) && value !== undefined,
    ),
  );
}
