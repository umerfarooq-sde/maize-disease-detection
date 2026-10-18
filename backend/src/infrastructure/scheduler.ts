import { randomUUID } from 'node:crypto';

export interface WorkerLease {
  acquire(identity: string): Promise<boolean>;
  renew(identity: string): Promise<boolean>;
  release(identity: string): Promise<void>;
}

/** One owned run; lease loss aborts child work and leaves durable journals intact. */
export async function runScheduledCycle(
  lease: WorkerLease,
  tasks: readonly ((signal: AbortSignal) => Promise<void>)[],
  stopping: AbortSignal,
  heartbeatMs = 30000,
  maximumMs = 600000,
): Promise<'completed' | 'busy'> {
  const identity = randomUUID();
  if (!(await lease.acquire(identity))) return 'busy';
  const abort = new AbortController();
  const stop = () => abort.abort();
  stopping.addEventListener('abort', stop, { once: true });
  if (stopping.aborted) abort.abort();
  let renewal: Promise<void> | undefined;
  let lost = false;
  const timer = setInterval(() => {
    if (renewal) return;
    renewal = lease
      .renew(identity)
      .then((held) => {
        if (!held) {
          lost = true;
          abort.abort();
        }
      })
      .catch(() => {
        lost = true;
        abort.abort();
      })
      .finally(() => {
        renewal = undefined;
      });
  }, heartbeatMs);
  const deadline = setTimeout(() => abort.abort(), maximumMs);
  try {
    for (const task of tasks) {
      if (abort.signal.aborted) throw new Error('Worker interrupted; durable work retained');
      await task(abort.signal);
    }
    if (lost || abort.signal.aborted) throw new Error('Worker lease or deadline lost');
    return 'completed';
  } finally {
    clearTimeout(deadline);
    clearInterval(timer);
    stopping.removeEventListener('abort', stop);
    await renewal;
    await lease.release(identity);
  }
}
