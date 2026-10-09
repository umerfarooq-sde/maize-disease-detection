"""Read-only relationship auditing; perceptual candidates never imply ground truth.

This inspects the already locked partitions. It neither creates splits nor changes
eligibility, and contains no model-input preprocessing or inference implementation.
"""

from collections import Counter, defaultdict
from collections.abc import Iterable, Mapping
from itertools import combinations
from pathlib import Path, PurePosixPath

from pydantic import JsonValue

from dataset_inventory import file_digest
from dataset_preparation import SPLIT_NAMES, SampleRecord, SplitName


def verify_artifact_hashes(directory: Path, expected: Mapping[str, str]) -> int:
    """Verify pinned files, refusing path escapes and changed files without modifying them."""
    root = directory.resolve(strict=True)
    for relative, digest in expected.items():
        member = PurePosixPath(relative)
        if (
            not relative
            or member.is_absolute()
            or "\\" in relative
            or any(part in {"..", "."} or ":" in part for part in relative.split("/"))
            or member.as_posix() != relative
            or len(digest) != 64
            or any(character not in "0123456789abcdef" for character in digest)
        ):
            raise ValueError("Artifact references require safe relative paths and SHA-256 hashes.")
        path = (root / relative).resolve(strict=True)
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError("Artifact reference escapes its directory or is not a file.")
        before = path.stat()
        actual = file_digest(path)
        after = path.stat()
        if (
            actual != digest
            or before.st_size != after.st_size
            or before.st_mtime_ns != after.st_mtime_ns
        ):
            raise ValueError("A pinned artifact hash or stable file identity does not match.")
    return len(expected)


def relationship_audit(
    partitions: Mapping[SplitName, tuple[SampleRecord, ...]],
    *,
    confirmed_edges: Iterable[tuple[str, str]] = (),
    excluded_contents: Iterable[str] = (),
) -> dict[str, JsonValue]:
    """Report every known identity intersection, including transitive group evidence.

    Callers first load/verify the immutable manifest. Keeping this pure allows
    deliberate broken partitions to be tested without modifying any dataset.
    """
    if set(partitions) != set(SPLIT_NAMES):
        raise ValueError("Audit requires exactly train, validation and test partitions.")
    attributes = ("sample_id", "content_hash", "pixel_hash", "group_id")
    identities: dict[str, dict[SplitName, set[str]]] = {
        name: {split: set() for split in SPLIT_NAMES}
        for name in (*attributes, "original_id", "original_uuid", "relative_path")
    }
    content_splits: dict[str, set[SplitName]] = defaultdict(set)
    all_rows: list[SampleRecord] = []
    for split, rows in partitions.items():
        if len({row.sample_id for row in rows}) != len(rows):
            raise ValueError("A partition contains repeated sample identifiers.")
        all_rows.extend(rows)
        for row in rows:
            content_splits[row.content_hash].add(split)
            for attribute in attributes:
                value = getattr(row, attribute)
                if isinstance(value, str):
                    identities[attribute][split].add(value)
            identities["original_id"][split].update(row.provenance.original_ids)
            identities["original_uuid"][split].update(row.provenance.original_uuids)
            identities["relative_path"][split].update((row.relative_path, *row.duplicate_paths))
    intersections: dict[str, JsonValue] = {}
    total_intersections = 0
    for first, second in combinations(SPLIT_NAMES, 2):
        counts = {
            name: len(by_split[first] & by_split[second]) for name, by_split in identities.items()
        }
        total_intersections += sum(counts.values())
        intersections[f"{first}/{second}"] = {name: value for name, value in counts.items()}

    edge_crossings: list[JsonValue] = []
    edge_counts = Counter[str]()
    for first_hash, second_hash in sorted({tuple(sorted(edge)) for edge in confirmed_edges}):
        first_splits, second_splits = (
            content_splits.get(first_hash, set()),
            content_splits.get(second_hash, set()),
        )
        if not first_splits and not second_splits:
            edge_counts["both_ineligible"] += 1
        elif not first_splits or not second_splits:
            edge_counts["one_ineligible"] += 1
        elif first_splits == second_splits and len(first_splits) == 1:
            edge_counts["same_partition"] += 1
        else:
            edge_counts["cross_partition"] += 1
            edge_crossings.append(
                {
                    "first_hash": first_hash,
                    "second_hash": second_hash,
                    "first_partitions": [str(value) for value in sorted(first_splits)],
                    "second_partitions": [str(value) for value in sorted(second_splits)],
                }
            )
    leaked_exclusions = sorted(set(excluded_contents) & set(content_splits))
    groups: dict[str, set[str]] = defaultdict(set)
    for row in all_rows:
        groups[row.group_id].add(row.label)
    mixed_groups = sorted(group for group, labels in groups.items() if len(labels) != 1)
    report: dict[str, JsonValue] = {
        "known_identity_overlap_count": total_intersections,
        "pairwise_intersections": intersections,
        "confirmed_edge_counts": dict(edge_counts),
        "confirmed_edge_crossings": edge_crossings,
        "excluded_contents_in_partitions": [str(value) for value in leaked_exclusions],
        "mixed_label_group_ids": [str(value) for value in mixed_groups],
        "eligible_unique_contents": len(content_splits),
        "eligible_groups": len(groups),
        "known_relationships_disjoint": not (
            total_intersections or edge_crossings or leaked_exclusions or mixed_groups
        ),
        "limitation": "Known identities do not prove unknown photo, plant or capture independence.",
    }
    return report
