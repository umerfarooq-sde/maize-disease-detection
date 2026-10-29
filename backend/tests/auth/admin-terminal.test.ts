import assert from 'node:assert/strict';
import { PassThrough, Writable } from 'node:stream';
import { test } from 'node:test';
import { createAdminTerminal } from '../../src/cli/admin-terminal.js';

class TerminalInput extends PassThrough {
  isTTY = true;
  isRaw = false;
  setRawMode(value: boolean) {
    this.isRaw = value;
    return this;
  }
}
function fixture() {
  const input = new TerminalInput();
  let displayed = '';
  const output = new Writable({
    write(chunk, _encoding, done) {
      displayed += chunk.toString();
      done();
    },
  });
  const terminal = createAdminTerminal(input, output);
  return { input, terminal, displayed: () => displayed };
}
test('password and confirmation are never echoed; Unicode/backspace editing and terminal restoration work', async () => {
  const f = fixture();
  try {
    const answer = f.terminal.ask('Password: ', true);
    f.input.write('synthetic-secret-🧪x\x7f\r');
    assert.equal(await answer, 'synthetic-secret-🧪');
    const confirmation = f.terminal.ask('Confirm: ', true);
    f.input.write('synthetic-secret-🧪\r');
    assert.equal(await confirmation, 'synthetic-secret-🧪');
    assert.equal(f.displayed(), 'Password: \nConfirm: \n');
  } finally {
    f.terminal.close();
  }
  assert.equal(f.input.isRaw, false);
});
test('Ctrl-C cancels hidden input without logging its buffer and restores raw mode', async () => {
  const f = fixture();
  try {
    const answer = f.terminal.ask('Password: ', true);
    f.input.write('do-not-print\x03');
    await assert.rejects(answer);
    assert.ok(!f.displayed().includes('do-not-print'));
  } finally {
    f.terminal.close();
  }
  assert.equal(f.input.isRaw, false);
});
test('terminal EOF cancels pending input and removes process signal handlers', async () => {
  const before = process.listenerCount('SIGTERM');
  const f = fixture();
  const answer = f.terminal.ask('Email: ');
  f.input.end();
  await assert.rejects(answer);
  f.terminal.close();
  assert.equal(process.listenerCount('SIGTERM'), before);
  assert.equal(f.input.isRaw, false);
});
