# Corrected research dataset index v2

This immutable metadata-only bundle preserves the exact verified v2 manifest and
its original integrity map. Four newly confirmed contradictory parent families
are excluded without relabeling or changing raw files. Confirmed shared leaf-region
parents are grouped before the existing seeded stratified allocation. The result
is 4,162 eligible contents in 4,121 groups, with 2,911 train, 627 validation and
624 test samples. V1 remains separately preserved.

Use `dataset_preparation.load_manifest()` and `verify_manifest()` with configured
`DATASET_PATH` before training. `confirmed-parent-relations.json` is the exact full
input evidence file whose hash is pinned by the manifest; `repair-evidence.json`
is its restricted schema representation. `independent-integrity.json` records the
separate all-source and parent-family closure check. `summary.json` gives compact
counts and identities; `export-integrity.json` pins every exported file.

V1 benchmark metrics cannot establish independent evaluation after the discovered
relationships. A fresh model is required for v2. This corrected partition is a
previously inspected public benchmark, not newly collected or never-inspected
external test data. Two unresolved parent candidates remain disclosed. Unknown
plant/session identities and field/source generalization are not certified.

No source images, review contact sheets, weights, absolute dataset paths or
camera/GPS metadata are distributed. Initial forensic inventories, similarity
screens and registered image reviews remain local and ignored; their hash
references record audit provenance rather than being required for standalone
manifest consumption. Current use remains non-commercial academic/FYP research,
with no commercial clearance and no raw-image redistribution.
