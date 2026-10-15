// Execute the SDK directly, without a shell or inherited server environment.
import { spawn, spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { flutterTestEnvironment } from './flutter-test-environment.mjs';

const environment = flutterTestEnvironment();
let executable = 'flutter';
let argumentsForSdk = process.argv.slice(2);
if (process.platform === 'win32') {
  const found = spawnSync('where.exe', ['flutter.bat'], { env: environment, encoding: 'utf8', windowsHide: true });
  const launcher = found.status === 0 ? found.stdout.trim().split(/\r?\n/)[0] : undefined;
  if (!launcher) throw new Error('Flutter SDK is not available on PATH.');
  environment.FLUTTER_ROOT = dirname(dirname(launcher));
  const cache = join(dirname(launcher), 'cache');
  executable = join(cache, 'dart-sdk', 'bin', 'dart.exe');
  argumentsForSdk = [join(cache, 'flutter_tools.snapshot'), ...argumentsForSdk];
}
const child = spawn(executable, argumentsForSdk, { env: environment, stdio: 'inherit', windowsHide: true });
child.once('error', () => { console.error('Flutter SDK could not start.'); process.exitCode = 1; });
child.once('exit', (code) => { process.exitCode = code ?? 1; });
