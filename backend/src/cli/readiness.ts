import { loadEnvironment } from '../config/environment.js';
try {
  const config = loadEnvironment();
  const port = process.env['OPERATIONS_PORT'] ?? config.PORT;
  const response = await fetch(`http://127.0.0.1:${port}/internal/ready`, {
    headers: { 'X-Operations-Token': config.OPERATIONS_TOKEN },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) process.exitCode = 1;
} catch {
  process.exitCode = 1;
}
