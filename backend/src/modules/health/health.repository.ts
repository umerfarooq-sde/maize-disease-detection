export interface HealthDatabase {
  $queryRaw(query: TemplateStringsArray): Promise<unknown>;
}

export interface HealthRepository {
  checkDatabase(): Promise<void>;
}

export function createHealthRepository(database: HealthDatabase): HealthRepository {
  return {
    async checkDatabase() {
      await database.$queryRaw`SELECT 1`;
    },
  };
}
