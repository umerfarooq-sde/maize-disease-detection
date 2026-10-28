// Launcher-only preload. Ask the existing application SIGBREAK handler to drain
// before Windows npm/tsx watcher termination can abruptly kill its child.
import { existsSync, writeFileSync } from 'node:fs';

const session = process.env.MAIZEDOCTOR_PHONE_SESSION;
const stop = process.env.MAIZEDOCTOR_PHONE_STOP;
const acknowledgement = process.env.MAIZEDOCTOR_PHONE_ACK;
if (session && /^[a-f0-9]{32}$/.test(session) && stop && acknowledgement) {
  const option = `--import=${import.meta.url}`;
  if (!(process.env.NODE_OPTIONS ?? '').includes(option)) {
    // Preserve existing server options; this environment never reaches Flutter.
    process.env.NODE_OPTIONS = `${process.env.NODE_OPTIONS ?? ''} ${option}`.trim();
  }
  if (/(?:^|[\\/])src[\\/]server\.ts$/.test(process.argv[1] ?? '')) {
    let requested = false;
    const timer = setInterval(() => {
      if (!requested && existsSync(stop) && process.listenerCount('SIGBREAK') > 0) {
        requested = true;
        clearInterval(timer);
        process.emit('SIGBREAK');
      }
    }, 200);
    timer.unref();
    process.once('exit', (exitCode) => {
      // Exit 0 follows the application's existing completed stop() promise.
      // Missing/nonzero acknowledgement is never called a graceful drain.
      if (requested && exitCode === 0) {
        try { writeFileSync(acknowledgement, session, { flag: 'wx' }); } catch { /* no false acknowledgement */ }
      }
    });
  }
}
