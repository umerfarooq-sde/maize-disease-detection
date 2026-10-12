"""Explicit operator ingestion/retrieval evaluation; no URL scraping or generation."""

import argparse
import json
from pathlib import Path

from pydantic import ValidationError

from app.config.settings import ConfigurationError, load_settings
from app.rag.corpus import load_corpus, read_json
from app.rag.evaluation import EvaluationSet, evaluate
from app.rag.service import create_retrieval_service
from app.utils.errors import AppError


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("check", "ingest"):
        command = commands.add_parser(name)
        command.add_argument("--corpus", type=Path, required=True)
        command.add_argument("--review", type=Path, required=True)
    evaluation = commands.add_parser("evaluate")
    evaluation.add_argument("--cases", type=Path, required=True)
    evaluation.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    service = None
    try:
        if arguments.command in {"check", "ingest"}:
            corpus = load_corpus(arguments.corpus, arguments.review)
            if arguments.command == "check":
                print(
                    json.dumps(
                        {
                            "corpusVersion": corpus.version,
                            "diseases": len(corpus.diseases),
                            "documents": len(corpus.documents),
                            "review": "verified",
                        }
                    )
                )
                return 0
        settings = load_settings()
        if not settings.rag_enabled:
            raise ConfigurationError()
        service = create_retrieval_service(settings)
        if arguments.command == "ingest":
            print(json.dumps(service.ingest(corpus)))
        else:
            # Reserve a new result before making provider calls; never overwrite.
            cases = EvaluationSet.model_validate(read_json(arguments.cases, max_bytes=65536))
            with arguments.output.open("x", encoding="utf-8") as output:
                result = evaluate(service, cases)
                json.dump(result, output, indent=2, allow_nan=False)
                output.write("\n")
            print(
                json.dumps({"totals": result["totals"], "meanDurationMs": result["meanDurationMs"]})
            )
        return 0
    except AppError as error:
        print(json.dumps({"error": error.code.value}))
        return 1
    except (OSError, ValueError, ValidationError, ConfigurationError):
        print(json.dumps({"error": "KNOWLEDGE_CONFIGURATION_OR_INPUT_INVALID"}))
        return 1
    finally:
        if service is not None:
            service.close()


if __name__ == "__main__":
    raise SystemExit(main())
