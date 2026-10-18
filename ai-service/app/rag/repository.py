"""Parameterized pgvector persistence. Source/chunk versions are never rewritten."""

import json
import logging
import re
from collections.abc import Iterator
from contextlib import contextmanager
from time import perf_counter
from typing import cast
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from uuid import UUID

import certifi
import psycopg
from psycopg import Connection
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.config.settings import Settings
from app.rag.chunking import CHUNKING_VERSION, Chunk, canonical_content, content_hash
from app.rag.connectivity import DatabaseConnector
from app.rag.embeddings import EMBEDDING_API_VERSION
from app.rag.schemas import Corpus, DocumentInput, RetrievalRequest, RetrievedChunk
from app.utils.errors import AppError, ErrorCode
from app.utils.logging import LOGGER_NAME, REQUEST_ID
from app.utils.metrics import observe


def database_failure_kind(error: psycopg.Error) -> str:
    """Classify locally; never serialize exception text containing credentials."""
    if error.sqlstate:
        return "SERVER_ERROR"
    if isinstance(error, psycopg.OperationalError):
        message = str(error).lower()
        if "timeout" in message or "timed out" in message or "deadline" in message:
            return "CONNECTION_TIMEOUT"
        if "certificate" in message or "ssl" in message or "tls" in message:
            return "TLS_FAILURE"
        if "resolve" in message or "translate host" in message:
            return "DNS_FAILURE"
        if "authentication" in message:
            return "AUTHENTICATION_FAILURE"
        return "CONNECTION_FAILURE"
    return "DRIVER_ERROR"


class KnowledgeRepository:
    def __init__(self, settings: Settings, identity: str) -> None:
        self.settings = settings
        self.identity = identity
        parsed = urlsplit(settings.database_url.get_secret_value())
        parameters = dict(parse_qsl(parsed.query))
        self.schema = parameters.pop("schema", "public")
        parameters.pop("pgbouncer", None)
        parameters.pop("uselibpqcompat", None)
        if not re.fullmatch(r"[a-z][a-z0-9_]{0,62}", self.schema):
            raise ValueError("Invalid retrieval database schema")
        if parameters.get("sslmode") in {"require", "prefer", "verify-ca"}:
            parameters["sslmode"] = "verify-full"
        if parameters.get("sslmode") == "verify-full" and "sslrootcert" not in parameters:
            # libpq requires an explicit root bundle on Windows. Keep hostname
            # verification enabled; use the bundled public CA roots, not an
            # insecure SSL alias or a machine-specific source path.
            parameters["sslrootcert"] = certifi.where()
        self.connection_url = urlunsplit(parsed._replace(query=urlencode(parameters)))
        self.connector = (
            DatabaseConnector(settings.database_connect_deadline_seconds)
            if settings.environment == "production"
            else None
        )

    def close(self) -> None:
        if self.connector:
            self.connector.close()

    @contextmanager
    def connection(self) -> Iterator[Connection[dict[str, object]]]:
        # Per-operation bounded connections avoid an idle pool in this small local
        # corpus. API capacity is bounded separately; no credentials are logged.
        stage = "CONNECT"
        started = perf_counter()
        try:
            with (
                self.connector.connect(self.connection_url)
                if self.connector
                else psycopg.connect(
                    self.connection_url,
                    connect_timeout=5,
                    row_factory=dict_row,
                )
            ) as connection:
                stage = "TRANSACTION_SETUP"
                if self.settings.environment == "production":
                    permissions = connection.execute(
                        "SELECT EXISTS (SELECT 1 FROM pg_catalog.pg_roles r "
                        "WHERE pg_catalog.pg_has_role(current_user,r.oid,'MEMBER') AND "
                        "(r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolbypassrls)) "
                        "AS privileged, EXISTS (SELECT 1 FROM pg_catalog.pg_class c "
                        "JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace "
                        "WHERE n.nspname NOT IN ('pg_catalog','information_schema') "
                        "AND pg_catalog.pg_has_role(current_user,c.relowner,'MEMBER')) "
                        "AS owns_objects, (pg_catalog.has_database_privilege("
                        "current_user,current_database(),'CREATE') OR "
                        "EXISTS (SELECT 1 FROM pg_catalog.pg_namespace n WHERE n.nspname NOT IN "
                        "('pg_catalog','information_schema') AND "
                        "pg_catalog.has_schema_privilege(current_user,n.oid,'CREATE'))) "
                        "AS can_create"
                    ).fetchone()
                    if permissions != {
                        "privileged": False,
                        "owns_objects": False,
                        "can_create": False,
                    }:
                        raise AppError(ErrorCode.RETRIEVAL_UNAVAILABLE)
                # Neon transaction pooling rejects startup `options`. Configure
                # each transaction explicitly so no pool-session setting leaks.
                connection.execute(
                    "SELECT set_config('search_path',%s,true), "
                    "set_config('statement_timeout','5000',true), "
                    "set_config('idle_in_transaction_session_timeout','15000',true)",
                    (self.schema,),
                )
                stage = "QUERY"
                yield cast(Connection[dict[str, object]], connection)
                stage = "COMMIT"
            observe("commit", "success", perf_counter() - started)
        except psycopg.Error as error:
            observe(
                "connect" if stage == "CONNECT" else "commit" if stage == "COMMIT" else "query",
                "failure",
                perf_counter() - started,
            )
            state = (
                error.sqlstate
                if error.sqlstate and re.fullmatch(r"[A-Z0-9]{5}", error.sqlstate)
                else "UNAVAILABLE"
            )
            logging.getLogger(LOGGER_NAME).error(
                "retrieval_database_failed:%s:%s:%s:%dms",
                state,
                stage,
                database_failure_kind(error),
                round((perf_counter() - started) * 1000),
                extra={
                    "event": "retrieval_database_failed",
                    "error_code": "DATABASE_" + state,
                    "database_stage": stage,
                    "database_failure_kind": database_failure_kind(error),
                    "duration_ms": round((perf_counter() - started) * 1000),
                    "request_id": REQUEST_ID.get(),
                },
            )
            raise AppError(ErrorCode.RETRIEVAL_UNAVAILABLE) from None

    def ping(self) -> None:
        with self.connection() as connection:
            connection.execute("SELECT embedding_version, metadata FROM knowledge_chunks LIMIT 0")
            row = connection.execute(
                "SELECT extversion FROM pg_extension WHERE extname='vector'"
            ).fetchone()
            if row is None:
                raise AppError(ErrorCode.RETRIEVAL_UNAVAILABLE)

    def record_operation(self, event: dict[str, object]) -> None:
        with self.connection() as connection:
            connection.execute("SET LOCAL statement_timeout = '750ms'")
            connection.execute(
                "INSERT INTO ai_operations "
                "(id,scope,operation,outcome,duration_ms,category,occurred_at) "
                "VALUES (%s::uuid,%s,%s,%s,%s,%s,%s) ON CONFLICT (id) DO NOTHING",
                tuple(
                    event[key]
                    for key in (
                        "id",
                        "scope",
                        "operation",
                        "outcome",
                        "durationMs",
                        "category",
                        "occurredAt",
                    )
                ),
            )

    def metadata(self, document: DocumentInput, corpus_version: str) -> dict[str, object]:
        return {
            "source": document.source.model_dump(mode="json", by_alias=True),
            "curation": document.metadata,
            "literalLabel": document.disease_label,
            "corpusVersion": corpus_version,
            "retrievalIdentity": self.identity,
            "chunking": {
                "version": CHUNKING_VERSION,
                "size": self.settings.rag_chunk_chars,
                "overlap": self.settings.rag_chunk_overlap,
            },
            "embedding": {
                "provider": "google",
                "model": self.settings.embedding_model,
                "version": self.settings.embedding_version,
                "dimensions": self.settings.embedding_dimensions,
                "normalization": "l2",
                "api": EMBEDDING_API_VERSION,
            },
        }

    def existing(self, document: DocumentInput, corpus_version: str) -> bool:
        with self.connection() as connection:
            return self._existing(connection, document, corpus_version)

    def _existing(
        self,
        connection: Connection[dict[str, object]],
        document: DocumentInput,
        corpus_version: str,
    ) -> bool:
        row = connection.execute(
            "SELECT id, content_hash, metadata, title, knowledge_type::text, status::text "
            "FROM knowledge_documents WHERE document_key=%s AND version=%s",
            (document.document_key, document.version),
        ).fetchone()
        if row is None:
            return False
        expected = self.metadata(document, corpus_version)
        stored = row["metadata"]
        # An unchanged document may be carried into a later corpus release.
        # Preserve its original corpus attribution instead of rewriting it.
        expected.pop("corpusVersion")
        same_metadata = (
            isinstance(stored, dict)
            and {key: value for key, value in stored.items() if key != "corpusVersion"} == expected
        )
        if (
            row["content_hash"] != content_hash(canonical_content(document.content))
            or not same_metadata
            or row["title"] != document.title
            or row["knowledge_type"] != document.knowledge_type
        ):
            raise AppError(ErrorCode.CONFLICT)
        # Reingestion never resurrects an archived/inactive historical version.
        if row["status"] != "ACTIVE":
            raise AppError(ErrorCode.CONFLICT)
        counts = connection.execute(
            "SELECT count(*) AS total, count(*) FILTER (WHERE embedding_status='READY' "
            "AND embedding_model=%s AND embedding_version=%s AND embedding_dimensions=%s) "
            "AS ready FROM knowledge_chunks WHERE document_id=%s",
            (
                self.settings.embedding_model,
                self.settings.embedding_version,
                self.settings.embedding_dimensions,
                row["id"],
            ),
        ).fetchone()
        if counts is None or counts["total"] == 0 or counts["total"] != counts["ready"]:
            raise AppError(ErrorCode.CONFLICT)
        return True

    def persist(
        self, corpus: Corpus, prepared: dict[str, list[tuple[Chunk, list[float]]]]
    ) -> dict[str, int]:
        created = skipped = 0
        with self.connection() as connection:
            # One controlled curation operation at a time, including two CLI
            # processes. External provider calls occur before this transaction.
            connection.execute(
                "SELECT pg_advisory_xact_lock("
                "hashtextextended('maizedoctor-knowledge-ingestion-v1',0))"
            )
            disease_ids: dict[str, object] = {}
            for disease in corpus.diseases:
                row = connection.execute(
                    "SELECT id, name, description, scientific_name FROM diseases WHERE slug=%s",
                    (disease.slug,),
                ).fetchone()
                if row is not None:
                    if (row["name"], row["description"], row["scientific_name"]) != (
                        disease.name,
                        disease.description,
                        disease.scientific_name,
                    ):
                        raise AppError(ErrorCode.CONFLICT)
                else:
                    row = connection.execute(
                        "INSERT INTO diseases(slug,name,description,scientific_name,status) "
                        "VALUES (%s,%s,%s,%s,'ACTIVE') RETURNING id",
                        (disease.slug, disease.name, disease.description, disease.scientific_name),
                    ).fetchone()
                if row is None:
                    raise AppError(ErrorCode.RETRIEVAL_UNAVAILABLE)
                disease_ids[disease.label] = row["id"]
            for document in sorted(corpus.documents, key=lambda item: item.document_key):
                if self._existing(connection, document, corpus.version):
                    skipped += 1
                    continue
                latest = connection.execute(
                    "SELECT max(version) AS version FROM knowledge_documents WHERE document_key=%s",
                    (document.document_key,),
                ).fetchone()
                if (
                    latest is not None
                    and latest["version"] is not None
                    and document.version <= int(cast(int, latest["version"]))
                ):
                    raise AppError(ErrorCode.CONFLICT)
                chunks = prepared.get(document.document_key)
                if not chunks:
                    raise AppError(ErrorCode.CONFLICT)
                disease_id = disease_ids[document.disease_label]
                source = document.source
                if (
                    connection.execute(
                        "SELECT id FROM disease_sources WHERE disease_id=%s AND url=%s",
                        (disease_id, str(source.url)),
                    ).fetchone()
                    is None
                ):
                    connection.execute(
                        "INSERT INTO disease_sources(disease_id,title,url,citation,publisher,"
                        "published_at,status) VALUES (%s,%s,%s,%s,%s,%s,'ACTIVE')",
                        (
                            disease_id,
                            source.title,
                            str(source.url),
                            source.rights,
                            source.publisher,
                            source.published_at,
                        ),
                    )
                connection.execute(
                    "UPDATE knowledge_documents SET status='ARCHIVED' "
                    "WHERE document_key=%s AND status='ACTIVE'",
                    (document.document_key,),
                )
                content = canonical_content(document.content)
                row = connection.execute(
                    "INSERT INTO knowledge_documents(document_key,version,title,content,"
                    "content_hash,source_reference,topic,language,status,disease_id,"
                    "knowledge_type,metadata) VALUES (%s,%s,%s,%s,%s,%s,'DISEASE','en',"
                    "'ACTIVE',%s,%s,%s) RETURNING id",
                    (
                        document.document_key,
                        document.version,
                        document.title,
                        content,
                        content_hash(content),
                        str(source.url),
                        disease_id,
                        document.knowledge_type,
                        Jsonb(self.metadata(document, corpus.version)),
                    ),
                ).fetchone()
                if row is None:
                    raise AppError(ErrorCode.RETRIEVAL_UNAVAILABLE)
                for chunk, vector in chunks:
                    connection.execute(
                        "INSERT INTO knowledge_chunks(document_id,chunk_index,content,"
                        "content_hash,embedding,embedding_model,embedding_version,"
                        "embedding_dimensions,embedding_status,metadata) "
                        "VALUES (%s,%s,%s,%s,%s::public.vector,%s,%s,%s,'READY',%s)",
                        (
                            row["id"],
                            chunk.index,
                            chunk.content,
                            chunk.sha256,
                            json.dumps(vector, allow_nan=False),
                            self.settings.embedding_model,
                            self.settings.embedding_version,
                            self.settings.embedding_dimensions,
                            Jsonb(
                                {
                                    "start": chunk.start,
                                    "end": chunk.end,
                                    "contentHash": chunk.sha256,
                                    "retrievalIdentity": self.identity,
                                }
                            ),
                        ),
                    )
                created += 1
        return {"created": created, "unchanged": skipped}

    def retrieve(self, request: RetrievalRequest, vector: list[float]) -> list[RetrievedChunk]:
        sql = """
        SELECT d.id AS "documentId", d.document_key AS "documentKey",
          d.version AS "documentVersion",
          c.id AS "chunkId", c.chunk_index AS "chunkIndex", c.content, d.title,
          d.metadata->>'literalLabel' AS "diseaseLabel", d.knowledge_type::text AS "knowledgeType",
          d.metadata->'source' AS source,
          1-(c.embedding OPERATOR(public.<=>) %s::public.vector) AS similarity,
          jsonb_build_object('curation', d.metadata->'curation',
            'corpusVersion', d.metadata->'corpusVersion', 'contentHash', c.content_hash,
            'start', c.metadata->'start', 'end', c.metadata->'end') AS metadata
        FROM knowledge_chunks c JOIN knowledge_documents d ON d.id=c.document_id
        JOIN diseases x ON x.id=d.disease_id
        WHERE d.status='ACTIVE' AND x.status='ACTIVE' AND d.topic='DISEASE' AND d.language='en'
          AND c.embedding_status='READY' AND c.embedding_model=%s AND c.embedding_version=%s
          AND c.embedding_dimensions=%s AND d.metadata->>'retrievalIdentity'=%s
        """
        parameters: list[object] = [
            json.dumps(vector, allow_nan=False),
            self.settings.embedding_model,
            self.settings.embedding_version,
            self.settings.embedding_dimensions,
            self.identity,
        ]
        if request.disease_label is not None:
            sql += " AND d.metadata->>'literalLabel'=%s"
            parameters.append(request.disease_label)
        if request.knowledge_type is not None:
            sql += " AND d.knowledge_type::text=%s"
            parameters.append(request.knowledge_type)
        if request.document_version is not None:
            sql += " AND d.version=%s"
            parameters.append(request.document_version)
        sql += " ORDER BY similarity DESC, d.document_key, c.chunk_index LIMIT %s"
        parameters.append(request.top_k)
        with self.connection() as connection:
            rows = connection.execute(sql, parameters).fetchall()
        # pgvector float32 rounding may exceed unit cosine bounds by an epsilon.
        for row in rows:
            row["similarity"] = max(-1.0, min(1.0, float(cast(float, row["similarity"]))))
        return [RetrievedChunk.model_validate(row) for row in rows]

    def draft(self, document_id: UUID) -> tuple[DocumentInput, dict[str, object]]:
        from app.rag.management import document_from_row

        with self.connection() as connection:
            row = connection.execute(
                "SELECT d.*,d.knowledge_type::text AS knowledge_type,x.slug AS disease_slug "
                "FROM knowledge_documents d JOIN diseases x ON x.id=d.disease_id "
                "WHERE d.id=%s AND d.status='DRAFT'",
                (document_id,),
            ).fetchone()
        if row is None:
            raise AppError(ErrorCode.CONFLICT)
        document = document_from_row(row)
        if row["disease_slug"] != document.disease_label.lower().replace("_", "-"):
            raise AppError(ErrorCode.CONFLICT)
        return document, cast(dict[str, object], row["metadata"])

    def _draft_indexed(
        self, connection: Connection[dict[str, object]], document_id: UUID, chunks: list[Chunk]
    ) -> bool:
        rows = connection.execute(
            "SELECT chunk_index,content,content_hash,metadata,embedding_status::text,"
            "embedding_model,embedding_version,embedding_dimensions FROM knowledge_chunks "
            "WHERE document_id=%s ORDER BY chunk_index LIMIT 33",
            (document_id,),
        ).fetchall()
        if not rows:
            return False
        if len(rows) != len(chunks):
            raise AppError(ErrorCode.CONFLICT)
        for row, chunk in zip(rows, chunks, strict=True):
            if (
                row["chunk_index"] != chunk.index
                or row["content"] != chunk.content
                or row["content_hash"] != chunk.sha256
                or row["embedding_status"] != "READY"
                or row["embedding_model"] != self.settings.embedding_model
                or row["embedding_version"] != self.settings.embedding_version
                or row["embedding_dimensions"] != self.settings.embedding_dimensions
                or row["metadata"]
                != {
                    "start": chunk.start,
                    "end": chunk.end,
                    "contentHash": chunk.sha256,
                    "retrievalIdentity": self.identity,
                }
            ):
                raise AppError(ErrorCode.CONFLICT)
        return True

    def draft_indexed(self, document_id: UUID, chunks: list[Chunk]) -> bool:
        with self.connection() as connection:
            return self._draft_indexed(connection, document_id, chunks)

    def save_draft_index(
        self,
        document_id: UUID,
        chunks: list[tuple[Chunk, list[float]]],
        actor_id: UUID,
        request_id: UUID,
    ) -> None:
        with self.connection() as connection:
            connection.execute(
                "SELECT pg_advisory_xact_lock("
                "hashtextextended('maizedoctor-knowledge-ingestion-v1',0))"
            )
            row = connection.execute(
                "SELECT status::text FROM knowledge_documents WHERE id=%s FOR UPDATE",
                (document_id,),
            ).fetchone()
            actor = connection.execute(
                "SELECT id FROM users WHERE id=%s AND role='ADMIN' AND status='ACTIVE'", (actor_id,)
            ).fetchone()
            if row is None or row["status"] != "DRAFT" or actor is None:
                raise AppError(ErrorCode.CONFLICT)
            if self._draft_indexed(connection, document_id, [chunk for chunk, _ in chunks]):
                return
            for chunk, vector in chunks:
                connection.execute(
                    "INSERT INTO knowledge_chunks(document_id,chunk_index,content,content_hash,"
                    "embedding,"
                    "embedding_model,embedding_version,embedding_dimensions,"
                    "embedding_status,metadata) "
                    "VALUES (%s,%s,%s,%s,%s::public.vector,%s,%s,%s,'READY',%s)",
                    (
                        document_id,
                        chunk.index,
                        chunk.content,
                        chunk.sha256,
                        json.dumps(vector, allow_nan=False),
                        self.settings.embedding_model,
                        self.settings.embedding_version,
                        self.settings.embedding_dimensions,
                        Jsonb(
                            {
                                "start": chunk.start,
                                "end": chunk.end,
                                "contentHash": chunk.sha256,
                                "retrievalIdentity": self.identity,
                            }
                        ),
                    ),
                )
            connection.execute(
                "INSERT INTO audit_logs(actor_id,action,entity_type,entity_id,request_id,changes) "
                "VALUES (%s,'UPDATE','knowledge_document',%s,%s,%s)",
                (
                    actor_id,
                    document_id,
                    str(request_id),
                    Jsonb(
                        {
                            "index": "READY",
                            "chunkCount": len(chunks),
                            "retrievalIdentity": self.identity,
                        }
                    ),
                ),
            )

    def reviewed_documents(self, chunks: list[RetrievedChunk]) -> list[DocumentInput]:
        from app.rag.management import document_from_row

        ids = list({chunk.document_id for chunk in chunks[:10]})
        if not ids:
            return []
        with self.connection() as connection:
            rows = connection.execute(
                "SELECT d.*,d.knowledge_type::text AS knowledge_type FROM knowledge_documents d "
                "JOIN diseases x ON x.id=d.disease_id WHERE d.id=ANY(%s) AND d.status='ACTIVE' "
                "AND x.status='ACTIVE' AND d.topic='DISEASE' AND d.language='en' "
                "AND d.metadata->>'retrievalIdentity'=%s AND d.metadata ? 'adminReview' "
                "AND EXISTS (SELECT 1 FROM audit_logs a WHERE a.entity_id=d.id "
                "AND a.entity_type='knowledge_document' AND a.action='ACTIVATE')",
                (ids, self.identity),
            ).fetchall()
        return [document_from_row(row) for row in rows]
