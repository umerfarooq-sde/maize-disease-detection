import { flutterTestEnvironment } from './flutter-test-environment.mjs';

export function flutterReleaseEnvironment(source = process.env) {
  const environment = flutterTestEnvironment(source);
  for (const name of ['MAIZEDOCTOR_KEYSTORE_FILE','MAIZEDOCTOR_KEYSTORE_PASSWORD','MAIZEDOCTOR_KEY_ALIAS','MAIZEDOCTOR_KEY_PASSWORD','MAIZEDOCTOR_UNSIGNED_VERIFICATION']) {
    if (source[name] !== undefined) environment[name] = source[name];
  }
  return environment;
}
