import { z } from 'zod';

export interface HealthDatabase {
  $queryRaw(query: TemplateStringsArray): Promise<unknown>;
}

export interface HealthRepository {
  checkDatabase(): Promise<void>;
}

export function createHealthRepository(
  database: HealthDatabase,
  requireLeastPrivilege = false,
): HealthRepository {
  return {
    async checkDatabase() {
      await database.$queryRaw`SELECT 1`;
      if (requireLeastPrivilege) {
        const result = await database.$queryRaw`
          SELECT EXISTS (SELECT 1 FROM pg_catalog.pg_roles r
            WHERE pg_catalog.pg_has_role(current_user,r.oid,'MEMBER')
            AND (r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolbypassrls)) AS privileged,
          EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname NOT IN ('pg_catalog','information_schema')
            AND pg_catalog.pg_has_role(current_user,c.relowner,'MEMBER')) AS owns_objects,
          (pg_catalog.has_database_privilege(current_user,current_database(),'CREATE') OR
            EXISTS (SELECT 1 FROM pg_catalog.pg_namespace n WHERE n.nspname NOT IN ('pg_catalog','information_schema')
            AND pg_catalog.has_schema_privilege(current_user,n.oid,'CREATE'))) AS can_create`;
        const permissions = z
          .array(
            z.strictObject({
              privileged: z.literal(false),
              owns_objects: z.literal(false),
              can_create: z.literal(false),
            }),
          )
          .length(1);
        if (!permissions.safeParse(result).success)
          throw new Error('Production runtime database privileges are unsafe.');
      }
    },
  };
}
