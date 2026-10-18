"""Exact application grants. Never applied to an existing managed provider implicitly."""

from database import connect, pg_environment
from psycopg import sql

ROLES = ("md_migrator", "md_node", "md_ai", "md_curator", "md_backup", "md_privacy")
NODE_WRITE = (
    "users",
    "farmer_profiles",
    "auth_sessions",
    "diseases",
    "disease_images",
    "disease_sources",
    "scans",
    "scan_uploads",
    "scan_predictions",
    "knowledge_documents",
    "fertilizers",
    "fertilizer_rules",
    "calculator_configs",
)
AI_READ = ("diseases", "knowledge_documents", "knowledge_chunks", "users", "audit_logs")


def provisioning_statements(database: str, passwords: dict[str, str], *, grants_only: bool = False):
    if not grants_only and (
        set(passwords) != set(ROLES) or any(len(value) < 32 for value in passwords.values())
    ):
        raise ValueError("Separate strong role credentials are required")
    statements = []
    if not grants_only:
        for role in ROLES:
            statements.extend(
                [
                    sql.SQL(
                        "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE roln"
                        "ame={}) THEN CREATE ROLE {}; END IF; END $$"
                    ).format(sql.Literal(role), sql.Identifier(role)),
                    sql.SQL(
                        "ALTER ROLE {} LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREAT"
                        "EROLE NOREPLICATION NOBYPASSRLS PASSWORD {}"
                    ).format(sql.Identifier(role), sql.Literal(passwords[role])),
                ]
            )
        statements.extend(
            [
                sql.SQL("ALTER DATABASE {} OWNER TO md_migrator").format(sql.Identifier(database)),
                sql.SQL("ALTER SCHEMA public OWNER TO md_migrator"),
                sql.SQL("REVOKE CREATE ON DATABASE {} FROM PUBLIC").format(
                    sql.Identifier(database)
                ),
                sql.SQL("REVOKE CREATE ON SCHEMA public FROM PUBLIC"),
                sql.SQL("CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public"),
                sql.SQL("GRANT USAGE ON TYPE public.vector TO md_migrator WITH GRANT OPTION"),
            ]
        )
    for role in ROLES:
        statements.append(
            sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(
                sql.Identifier(database), sql.Identifier(role)
            )
        )
        statements.append(
            sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(sql.Identifier(role))
        )
    if grants_only:
        statements.append(sql.SQL("GRANT SELECT ON ALL TABLES IN SCHEMA public TO md_backup"))
        statements.append(
            sql.SQL(
                "GRANT SELECT, INSERT (id,user_id,status,assets,created_at,up"
                "dated_at) ON public.privacy_requests TO md_node"
            )
        )
        for table in (
            *NODE_WRITE,
            "audit_logs",
            "ai_operations",
            "knowledge_chunks",
            "model_versions",
        ):
            statements.append(
                sql.SQL("GRANT SELECT ON public.{} TO md_node").format(sql.Identifier(table))
            )
        for table in NODE_WRITE:
            statements.append(
                sql.SQL("GRANT INSERT, UPDATE ON public.{} TO md_node").format(
                    sql.Identifier(table)
                )
            )
        # Session cleanup/idempotency retirement; no audit deletion by application roles.
        for table in ("auth_sessions", "scan_uploads"):
            statements.append(
                sql.SQL("GRANT DELETE ON public.{} TO md_node").format(sql.Identifier(table))
            )
        for table in ("audit_logs", "ai_operations"):
            statements.append(
                sql.SQL("GRANT INSERT ON public.{} TO md_node").format(sql.Identifier(table))
            )
        for table in AI_READ:
            statements.append(
                sql.SQL("GRANT SELECT ON public.{} TO md_ai").format(sql.Identifier(table))
            )
        statements.extend(
            [
                sql.SQL("GRANT SELECT, INSERT ON public.knowledge_chunks TO md_ai"),
                # The authenticated Admin draft-index operation fences its
                # document with SELECT FOR UPDATE. No content/status write grant.
                sql.SQL("GRANT UPDATE (id) ON public.knowledge_documents TO md_ai"),
                sql.SQL("GRANT INSERT ON public.audit_logs,public.ai_operations TO md_ai"),
                # ON CONFLICT (id) DO NOTHING checks the conflict-target column.
                # No telemetry payload/outcome read access is required by the writer.
                sql.SQL("GRANT SELECT (id) ON public.ai_operations TO md_ai"),
                sql.SQL(
                    "GRANT SELECT, INSERT, UPDATE ON public.diseases,public.disea"
                    "se_sources,public.knowledge_documents,public.knowledge_chunk"
                    "s TO md_curator"
                ),
                sql.SQL("GRANT USAGE ON TYPE public.vector TO md_node,md_ai,md_curator"),
                sql.SQL(
                    "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO md_"
                    "node,md_ai,md_curator"
                ),
                sql.SQL(
                    "GRANT SELECT ON public.users,public.farmer_profiles,public.a"
                    "uth_sessions,public.scans,public.scan_uploads,public.scan_pr"
                    "edictions,public.ai_queries,public.ai_responses,public.histo"
                    "ry,public.notifications,public.privacy_requests,public.ai_op"
                    "erations TO md_privacy"
                ),
                sql.SQL(
                    "GRANT UPDATE ON public.users,public.auth_sessions,public.pri"
                    "vacy_requests TO md_privacy"
                ),
                sql.SQL(
                    "GRANT DELETE ON public.users,public.auth_sessions,public.sca"
                    "ns,public.scan_uploads,public.scan_predictions,public.ai_que"
                    "ries,public.ai_responses,public.history,public.notifications"
                    ",public.ai_operations TO md_privacy"
                ),
                sql.SQL("GRANT INSERT ON public.audit_logs TO md_privacy"),
                # SELECT FOR UPDATE requires UPDATE on at least one column. These
                # grants permit row fencing, not changing private content fields.
                sql.SQL("GRANT UPDATE (id) ON public.scans,public.farmer_profiles TO md_privacy"),
                sql.SQL(
                    "GRANT UPDATE (state,scan_id,updated_at) ON public.scan_uploads TO md_privacy"
                ),
                sql.SQL("GRANT INSERT ON public.scan_uploads TO md_privacy"),
                # Future schema changes require this explicit idempotent grant pass.
                sql.SQL(
                    "ALTER DEFAULT PRIVILEGES FOR ROLE md_migrator IN SCHEMA publ"
                    "ic REVOKE ALL ON TABLES FROM PUBLIC"
                ),
            ]
        )
    return statements


def provision(
    url: str, passwords: dict[str, str], *, grants_only=False, allow_managed=False
) -> dict:
    env = pg_environment(url)
    if not allow_managed and env["PGHOST"] not in {
        "postgres",
        "localhost",
        "127.0.0.1",
        "::1",
    }:
        raise ValueError(
            "Managed role changes require separate explicit authorization; generate SQL instead"
        )
    with connect(url) as connection:
        for statement in provisioning_statements(
            env["PGDATABASE"], passwords, grants_only=grants_only
        ):
            connection.execute(statement)
    return {"status": "PASS", "roles": list(ROLES), "grantsOnly": grants_only}


def audit(url: str, expected: str) -> dict:
    if expected not in {"md_node", "md_ai", "md_backup", "md_privacy"}:
        raise ValueError("Unknown runtime identity")
    with connect(url) as connection:
        connection.execute("SET TRANSACTION READ ONLY")
        row = connection.execute(
            "SELECT current_user, EXISTS (SELECT 1 FROM pg_roles r WHERE "
            "pg_has_role(current_user,r.oid,'MEMBER') AND (r.rolsuper OR "
            "r.rolcreatedb OR r.rolcreaterole OR r.rolbypassrls)), EXISTS"
            " (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.re"
            "lnamespace WHERE n.nspname='public' AND pg_has_role(current_"
            "user,c.relowner,'MEMBER')),has_schema_privilege(current_user"
            ",'public','CREATE'),has_database_privilege(current_user,current_database(),'CREATE')"
        ).fetchone()
        if row != (expected, False, False, False, False):
            raise ValueError("Unsafe runtime privileges")
        assert connection.execute("SELECT 1").fetchone() == (1,)
        if expected == "md_ai":
            assert not connection.execute(
                "SELECT has_table_privilege(current_user,'users','UPDATE')"
            ).fetchone()[0]
        assert not connection.execute(
            "SELECT has_table_privilege(current_user,'audit_logs','DELETE')"
        ).fetchone()[0]
        secured = bool(connection.pgconn.ssl_in_use)
    return {
        "status": "PASS",
        "identity": expected,
        "clientTLS": secured,
        "privileged": False,
        "ownsObjects": False,
        "canCreate": False,
    }
