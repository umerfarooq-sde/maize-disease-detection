# Versioned dataset manifests

These are immutable **metadata-only** research indices, not redistributed source
images. They record relative filenames, content/group identities, literal labels,
exclusions, fixed partitions, public source provenance and research restrictions.
The raw dataset remains external and is resolved only through `DATASET_PATH`.

Use `maize-research-20261008-v2/manifest.json` for the corrected research baseline.
The v1 index remains immutable for historical reproducibility; confirmed transformed
parent families crossed its partitions, invalidating independent-evaluation claims.
V2 groups all confirmed relationships and excludes entire newly conflicting families
without editing or relabeling source images. See
[the repair](maize-research-20261008-v2/README.md) and
[fitness audit](../../docs/26-model-fitness-validation.md).

Its companion `summary.json` provides class/partition counts and both semantic and
file hashes. `dataset_preparation.load_manifest()` validates fingerprint, class/policy,
dispositions and group separation; `verify_manifest()` also validates current source
bytes. Never edit a version to reshuffle partitions or improve reported metrics.
Create a separately reviewed new dataset version when eligibility or evidence changes.

No raw pixels, local absolute paths, GPS/camera/owner metadata or commercial permission
are included. Model binaries and experiment outputs remain local/ignored. Source
declarations and current non-commercial academic/FYP restrictions remain binding.
