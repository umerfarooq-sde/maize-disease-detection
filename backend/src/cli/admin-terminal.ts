import { createInterface } from 'node:readline/promises';
import { type Readable, Writable } from 'node:stream';
import type { AdminTerminal } from './admin-seed.js';

/** Native readline owns editing/raw-mode restoration; hidden output is discarded.
 * No password echo, history, subprocess argument, temporary file or dependency. */
export function createAdminTerminal(
  input: Readable = process.stdin,
  output: Writable = process.stdout,
): AdminTerminal {
  let hidden = false;
  const abort = new AbortController();
  const display = new Writable({
    write(chunk, _encoding, callback) {
      if (!hidden) output.write(chunk);
      callback();
    },
  });
  const reader = createInterface({ input, output: display, terminal: true, historySize: 0 });
  const cancel = () => abort.abort();
  reader.on('SIGINT', cancel);
  reader.on('close', cancel);
  process.on('SIGTERM', cancel);
  process.on('SIGBREAK', cancel);
  return {
    async ask(label, secret = false) {
      if (abort.signal.aborted) throw new Error('Input cancelled.');
      hidden = secret;
      if (secret) output.write(label);
      try {
        return await reader.question(secret ? '' : label, { signal: abort.signal });
      } finally {
        hidden = false;
        if (secret) output.write('\n');
      }
    },
    write(message) {
      output.write(`${message}\n`);
    },
    close() {
      cancel();
      reader.close();
      process.off('SIGTERM', cancel);
      process.off('SIGBREAK', cancel);
      display.end();
    },
  };
}
