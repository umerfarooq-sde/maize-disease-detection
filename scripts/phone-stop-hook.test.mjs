import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { flutterTestEnvironment } from './flutter-test-environment.mjs';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const hook = new URL('./phone-stop-hook.mjs', import.meta.url).href;

async function fixture(t, successful) {
  const cache = join(root, '.cache/phone');
  mkdirSync(cache, { recursive: true });
  const directory = mkdtempSync(join(cache, 'hook-test-'));
  mkdirSync(join(directory, 'src'));
  const file = join(directory, 'src/server.ts');
  const stop = join(directory, 'node.stop');
  const ack = join(directory, 'node-app-stopped');
  const ready = join(directory, 'ready');
  const drained = join(directory, 'drained');
  const session = randomUUID().replaceAll('-', '');
  writeFileSync(file, `
    import {writeFileSync} from 'node:fs';
    const keepAlive=setInterval(()=>{},1000);
    process.once('SIGBREAK',()=>{
      setTimeout(()=>{
        writeFileSync(${JSON.stringify(drained)},'drain completed');
        clearInterval(keepAlive);
        process.exitCode=${successful ? 0 : 1};
      },50);
    });
    writeFileSync(${JSON.stringify(ready)},process.env.NODE_OPTIONS ?? '');
  `);
  const child = spawn(process.execPath, ['--import', hook, file], {
    windowsHide: true, stdio: 'ignore',
    env: { ...flutterTestEnvironment(), NODE_OPTIONS: '--trace-warnings', MAIZEDOCTOR_PHONE_SESSION: session,
      MAIZEDOCTOR_PHONE_STOP: stop, MAIZEDOCTOR_PHONE_ACK: ack },
  });
  t.after(() => { if (child.exitCode === null) child.kill(); });
  const exited = new Promise((resolve, reject) => {
    child.once('exit', resolve);
    child.once('error', reject);
  });
  for (let attempt = 0; !existsSync(ready); attempt++) {
    assert.ok(attempt < 100, 'fixture must register its existing shutdown handler');
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  assert.ok(readFileSync(ready, 'utf8').includes('--trace-warnings'), 'existing Node options are preserved');
  writeFileSync(stop, session);
  return { code: await exited, ack, drained, session };
}

test('owned application drains before a session-fenced success acknowledgement', { timeout: 10000 }, async t => {
  const result = await fixture(t, true);
  assert.equal(result.code, 0);
  assert.ok(existsSync(result.drained));
  assert.equal(readFileSync(result.ack, 'utf8'), result.session);
});

test('failed application shutdown cannot acknowledge a successful drain', { timeout: 10000 }, async t => {
  const result = await fixture(t, false);
  assert.equal(result.code, 1);
  assert.ok(!existsSync(result.ack));
});
