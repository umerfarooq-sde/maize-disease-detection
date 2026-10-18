import { appendFileSync, existsSync, mkdirSync, renameSync, statSync, unlinkSync } from 'node:fs';
import { resolve } from 'node:path';
import type { DestinationStream } from 'pino';

const fields = new Set([
  'level',
  'time',
  'service',
  'event',
  'code',
  'method',
  'route',
  'statusCode',
  'status',
  'durationMs',
  'count',
  'reason',
]);

// Separate allowlisted central log projection. Console logging keeps its existing
// redaction policy. A failed optional sink must never break an API operation.
export function safeLogFile(directory: string): DestinationStream {
  const file = resolve(directory, 'node.jsonl');
  mkdirSync(directory, { recursive: true, mode: 0o750 });
  return {
    write(line: string) {
      try {
        const parsed: unknown = JSON.parse(line);
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return;
        const safe: Record<string, string | number> = {};
        for (const [key, value] of Object.entries(parsed)) {
          if (
            fields.has(key) &&
            ((typeof value === 'string' && value.length <= 160) ||
              (typeof value === 'number' && Number.isFinite(value)))
          )
            safe[key] = value;
        }
        if (existsSync(file) && statSync(file).size >= 10485760) {
          if (existsSync(`${file}.1`)) unlinkSync(`${file}.1`);
          renameSync(file, `${file}.1`);
        }
        appendFileSync(file, `${JSON.stringify(safe)}\n`, { mode: 0o640 });
      } catch {
        process.stderr.write('{"event":"safe_log_sink_failed"}\n');
      }
    },
  };
}
