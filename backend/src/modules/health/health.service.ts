import type { HealthRepository } from './health.repository.js';

export interface HealthStatus {
  status: 'ok' | 'degraded';
  service: 'maizedoctor-backend';
  timestamp: string;
  uptimeSeconds: number;
  checks: { database: 'up' | 'down' };
}

export function createHealthService(repository: HealthRepository) {
  return {
    async getHealth(): Promise<HealthStatus> {
      let database: 'up' | 'down' = 'up';
      try {
        await repository.checkDatabase();
      } catch {
        database = 'down';
      }
      return {
        status: database === 'up' ? 'ok' : 'degraded',
        service: 'maizedoctor-backend',
        timestamp: new Date().toISOString(),
        uptimeSeconds: Math.floor(process.uptime()),
        checks: { database },
      };
    },
  };
}

export type HealthService = ReturnType<typeof createHealthService>;
