# Phase 9.5 — dataset intake and real-image preprocessing review

Historical review. The user subsequently approved exclusions, academic/FYP research
use and full-frame preprocessing, and authorized Phase 10. Those approvals are recorded
in [DECISIONS.md](DECISIONS.md); [PROJECT_STATE.md](PROJECT_STATE.md) gives current progress.
The readiness questions below describe the review checkpoint before that approval.

Reviewed: 2026-10-07. The user supplied one absolute dataset path. It is configured
in ignored `ml-training/.env`; ignored inventory artifacts also record the source path.
This document refers to `DATASET_PATH`. No source
image was changed, renamed, deleted or augmented. No classifier, tuning, permanent
partition or manually preprocessed training dataset was created.

## DATASET STATUS

**NOT READY FOR TRAINING.** Dataset discovery and real-image review are complete;
the previous missing-data/synthetic-only blockers are resolved. Remaining decisions
concern exclusion of contradictory labels/invalid files, use permissions, and approval
of the recommended full-frame training/serving policy. There is no need for the user
to reconstruct labels, source archives, splits or metadata recovered from the files.

The eventual Phase 10 can perform recorded manifest exclusions and grouped splitting;
these are not reasons to rename/delete originals or create partitions during Phase 9.5.
Do not begin training automatically.

## DATASET INVENTORY

Actual source path and per-file facts are in ignored
`.cache/dataset-review/phase95-20261007/summary.json`, `inventory.json`, `inventory.csv`
and the configured local environment. The source has four flat class folders, no
subfolders, no README/license/CSV files and no train/validation/test directories.

| Fact | Actual result |
|---|---:|
| Image filenames | 8,040 |
| Extensions | 8,039 .jpg/.JPG; one .jpeg |
| Decoded formats | 8,035 JPEG; four PNG disguised as .jpg; one three-frame MPO |
| Pixel modes | 8,035 RGB; four RGBA; one CMYK |
| Total bytes | 223,407,731 (about 213 MiB) |
| File bytes min / median / p95 / max | 3,874 / 13,897.5 / 20,813 / 6,574,069 |
| Dimension combinations | 266 |
| 256×256 images | 7,704 |
| Aspect ratio min / median / p95 / max | 0.28785 / 1 / 1 / 3.74790 |
| Minimum width / height | 180 / 116 (different images) |
| Maximum dimension | 5,184; two images are 5,184×3,456 or its portrait counterpart |
| Side below 32 | 0 |
| Side below 128 | 1: Common_Rust (1751).jpg, 292×116 |
| Files over 5 MiB | 3 |
| Files over 16 million pixels | 2 |
| Non-image/unknown-extension files | 0 |

All 8,040 headers/hashes were inspected. Inventory decoded/verified 8,038 within its
pixel analysis cap; two larger originals were header-inspected rather than allocated.
No unreadable/corrupt file was found in the inspected range. Two analysis-limit entries
must not be described as corrupt images. Both shared policies were attempted on every
file; their authoritative limits reject oversized inputs safely.

## DISCOVERED LABELS

Exact directory labels, preserved without normalization or merging:

- `Common_Rust`
- `Gray_Leaf_Spot`
- `Healthy`
- `Northern_Corn_Leaf_Blight`

Folder spelling/capitalization variants, mixed/unknown/other label folders and unlabeled
images: none. Healthy is explicitly represented. Directory structure answers the label
question; no manual class list is needed. However, content-level contradictory labels
exist below. Supervised adjudication/class-map finalization stops at those groups.

## CLASS DISTRIBUTION

| Exact label | Files | Distinct byte contents within label | Shared-valid files | Distinct shared-valid contents within label |
|---|---:|---:|---:|---:|
| Common_Rust | 2,498 | 1,306 | 2,493 | 1,301 |
| Gray_Leaf_Spot | 1,087 | 574 | 1,084 | 571 |
| Healthy | 2,324 | 1,162 | 2,324 | 1,162 |
| Northern_Corn_Leaf_Blight | 2,131 | 1,146 | 2,128 | 1,143 |

Distinct-per-label columns count the two exact conflicting contents in both labels;
their totals therefore exceed global uniqueness by two. Global byte-unique pool:
**4,186**; shared-valid byte-unique pool: **4,175**. Rust/gray raw-file imbalance is
about 2.30:1, and distinct-content imbalance about 2.28:1. Counts must be recomputed
after inclusion/conflict/relationship decisions; merged duplicate counts are not
independent training examples.

## CORRUPT / INVALID FILES

Both shared policies reject the same 11 files (0.137%); originals remain untouched.
Paths below are dataset-relative, with exact filename spelling retained.

| Relative path | Reason |
|---|---|
| Common_Rust/Common_Rust (1730).jpg | PNG bytes, misleading JPEG extension: FORMAT_MISMATCH |
| Common_Rust/Common_Rust (1733).jpg | Three-frame MPO: ANIMATED_IMAGE |
| Common_Rust/Common_Rust (1747).jpg | PNG bytes, misleading JPEG extension: FORMAT_MISMATCH |
| Common_Rust/Common_Rust (1753).jpg | 6,483,951 bytes: IMAGE_TOO_LARGE |
| Common_Rust/Common_Rust (1755).jpg | PNG bytes, misleading JPEG extension: FORMAT_MISMATCH |
| Gray_Leaf_Spot/Gray_Leaf_Spot (303).jpg | PNG bytes, misleading JPEG extension: FORMAT_MISMATCH |
| Gray_Leaf_Spot/Gray_Leaf_Spot (575).jpg | INVALID_COLOR_PROFILE |
| Gray_Leaf_Spot/Gray_Leaf_Spot (686).jpg | 5,693,806 bytes; also 17,915,904 pixels: IMAGE_TOO_LARGE |
| Northern_Corn_Leaf_Blight/Northern_Corn_Leaf_Blight (1873).jpg | INVALID_COLOR_PROFILE |
| Northern_Corn_Leaf_Blight/Northern_Corn_Leaf_Blight (678).jpg | 17,915,904 pixels: INVALID_DIMENSIONS |
| Northern_Corn_Leaf_Blight/Northern_Corn_Leaf_Blight (727).jpg | 6,574,069 bytes: IMAGE_TOO_LARGE |

These are known admissibility failures, not eleven unreadable images. Recommended
default: record their exclusion from the future training index. No source rename,
in-place conversion, validation relaxation or manual preprocessing is required.
Any future repair/ingestion policy must preserve originals and shared serving parity.

## DUPLICATE / NEAR-DUPLICATE FINDINGS

SHA256 identifies **3,854 exact duplicate pairs/groups and 3,854 excess copies**.
Decoded-RGB hashes find the same groups, with no additional pixel-identical group.
RGB hashes alone omit alpha/profile semantics and are only candidate evidence in
general; these actual duplicate groups contain no mixed-mode/RGBA members.

All 3,852 PlantVillage maize color images already occur in the other source archive.
Adding that archive supplied zero new independent color contents. The other two exact
groups already conflict within the source Corn collection.

Perceptual screening used pHash Hamming ≤ 4 and dHash ≤ 6, excluding exact/pixel matches.
It found 22 path-pair records, representing **10 unique content pairs/20 contents**.
All 22 pairs were visually inspected and show strong same-photograph/re-encoding/crop/
edit relationships. These are ten candidate parent groups, not 22 independent originals
or an exhaustive derivative detector. The matcher is orientation-sensitive.

Cross-label relations involve **seven filenames/five byte contents**:

1. Gray_Leaf_Spot (414).jpg = Northern_Corn_Leaf_Blight (553).jpg; Blight (529).jpg
   is a visually matching 90°-rotated derivative, missed by the hash threshold.
2. Gray_Leaf_Spot (877).jpg = Northern_Corn_Leaf_Blight (1828).jpg.
3. Gray_Leaf_Spot (538).jpg and Northern_Corn_Leaf_Blight (1772).jpg visibly show
   the same watermarked multi-leaf photo with different encoding/content hashes.

No class was selected automatically for these families. Recommended default: exclude
all related members from future supervised partitions until qualified adjudication.
Pair reviews are in ignored `.cache/phase95-pair-review/`; per-pair facts are in
`near-duplicate-candidates.json` and `.cache/phase95-manual-review.json`.

## AUGMENTATION / DERIVATIVE FINDINGS

No filename declares augmentation/flip/rotation/crop. All current bytes match recovered
source archive members; this does not certify original camera data. Most are already
256×256 publisher images, and some carry editing/recompression metadata.

Confirmed evidence includes the duplicate merge, visually related edit/re-encoding/
crop pairs and the rotated Blight 529 derivative. Intentional training augmentation
history cannot be determined from this alone. The source PlantVillage archive contains
color/grayscale/segmented siblings, but none of the supplied files originate from its
grayscale/segmented branches. Those branches are variants, not train/test partitions.
Any eventual use of them must share the original-image group and serving policy.

## PROVENANCE STATUS

**Known:** Windows download-origin metadata identifies two existing source archives;
every current file matches its declared archive SHA256. The Corn archive contributes
4,188 files; the PlantVillage color branch contributes 3,852. Recovered original filename
identity covers 7,704 current files / 3,852 source identities; explicit UUID identity covers
5,320 current files / 2,660 identifiers. Original filenames identify images, not plants.
No official split is present in the supplied folders or the recovered archive structures.

The [Corn/Maize publisher](https://www.kaggle.com/datasets/smaranjitghose/corn-or-maize-leaf-disease-dataset)
describes a selected PlantVillage/PlantDoc merge and retains original-author rights.
The [PlantVillage publisher](https://www.kaggle.com/datasets/abdallahalidev/plantvillage-dataset)
declares CC BY-NC-SA 4.0. Embedded rights include CIMMYT non-commercial/share-alike
notices and an all-rights-reserved stock-photo notice on Blight (1851).jpg. Download
availability does not establish uniform use permission; intended use/contrary rights
remain decisions rather than invented metadata.

Metadata counts: 167 EXIF, 73 IPTC, 70 JPEG comments, 136 XMP; 144 original timestamps,
18 ImageUniqueID fields. These overlap. Some GPS fields exist; exact coordinates,
camera serials, owner details and private archive paths stay in ignored artifacts.
Repeated timestamps/EXIF IDs can be copied processing/device metadata. A seven-image
shared-ID family contains differing scenes/dates plus a known duplicate/rotation;
do not blindly turn that ID into one augmentation parent or verified capture group.

**Unknown:** complete independent plant/field/session mappings, label adjudication for
the three conflicting families, uniform permission for underlying web photographs,
and full pre-publication edit history. These limits should be disclosed, not converted
into a demand for the user to fabricate metadata. Source labels, sources, licensing
declarations and absence of splits have already been determined from the files.

Ignored source reports: `.cache/phase95-provenance.md`, `phase95-source-linkage.json`,
`phase95-source-index.json`, `phase95-download-zones.json`, `phase95-capture-metadata.json`.

## PREPROCESSING REAL-IMAGE RESULTS

Ran the exact shared 1.0.0 pipeline on every image using conservative and disabled
segmentation. Neither consumer owns a second transform. Default 224×224, RGB CHW
float32, bilinear aspect-preserving letterbox, mean 0/std 1 ([0,1]) remain explicit
foundation values, not a trained classifier configuration.

| Outcome | Conservative | Full-frame |
|---|---:|---:|
| Accepted | 8,029 | 8,029 |
| Rejected | 11 | 11 |
| Segmented | 8 files / 4 unique Rust contents | 0 (disabled by policy) |
| Full-frame fallback | 8,021 | Not applicable |
| Heterogeneous-border fallback | 8,017 | Not applicable |
| Foreground-touches-border fallback | 4 | Not applicable |

Valid outputs have shape (3, 224, 224), float32, finite values in [0, 1]. Training and AI
consumer comparisons on 80 real files × two configurations produce **160 passing parity
cases**, including masks, original/config/version metadata, RGB/crop/final arrays,
normalization, bounds, exact model/tensor values and repeated-call determinism.
Config hashes differ between policies as expected; they match across consumers for
the same policy. Canonical conservative config hash remains
`77561635e69fafbda50a75ed7c7b2e59a95f858f45420f89079b855a9b1e7f27`.

Twenty purposive samples per exact class cover brightness/sharpness, dimensions,
aspect/size extremes, extraction cases and evenly spaced files. The 80 samples represent
77 unique contents; an extra missing extraction family makes the primary visual review
**81 filenames/78 contents**. Additional duplicate/conflict/metadata-family sheets were
also inspected. This is purposive review, not an unbiased semantic-accuracy estimate.

Visual output directory: `.cache/dataset-review/phase95-20261007/`. Each `samples/NNN/`
contains extraction/full-frame debug bundles and comparison.png; 20 paged class sheets
show original standardized RGB, mask, extracted/background-replaced crop, final
extraction input and final full-frame input. Native-size standardized.png/mask.png
provide detail beyond thumbnails. Full-frame originals need no separate transformed
training dataset. Review files remain ignored and contain licensed/private image content.

## LESION PRESERVATION RESULTS

Viewed all 80 comparison samples and the fourth independent extracted Rust family.
No obvious preprocessing-caused deletion of visible lesion/tissue/leaf edges was
observed in this primary sample. This is visual evidence with no annotated pixel masks,
not zero global failure or certified pathology/field accuracy.

| Visual characteristic | Observed evidence / limitation |
|---|---|
| Yellow/pale chlorosis | Rust field examples 1726/1751 and gray-leaf-spot examples retain yellow/pale regions; full-frame fallback introduces no extraction deletion. |
| Brown/rust puncta | All four extracted contents and full-frame examples retain visible puncta; small spots soften in final 224 input. |
| Gray/tan elongated lesions | Gray examples 477/174/277 and blight examples 1804/1906 retain regions and surrounding tissue. |
| Blight/necrotic/dead tissue | Blight examples 1210/1501/1602/1703 retain dry/brown/edge tissue; no green-only hue filtering. |
| Leaf edges/tips | Four unique extracted Rust contents retain visible silhouette/tips; other reviewed leaves keep full frame. Source photographs already clip some leaves. |
| Clutter/multiple/partial leaves | Full-frame preserves context but backgrounds/hands/watermarks remain and may become shortcuts. |
| Bright/dark/blur/high-resolution | Geometry/color remains consistent; fine detail can disappear through resize, especially wide field scenes. Blur is not repaired or semantically rejected. |

There is no semantic maize detector/no-leaf quality classifier. No reviewed primary
sample was obviously leaf-free; that does not prove every dataset image contains an
appropriate leaf. Current resized-source limitations cannot be recovered by preprocessing.

## SEGMENTATION FAILURES

Conservative extraction falls back in **99.900% of 8,029 accepted files**. This measures
background-extraction applicability, not lesion deletion. Fallback deliberately keeps
the full standardized frame. No excessive crop was observed in the reviewed four
extracted contents; one retains 69.53% of frame area, two 100%, one 98.44%. Their masks
keep roughly 36.9–49.4% of pixels and sometimes retain a dark rim around the leaf.

Background removal is ineffective for nearly the entire dataset; field clutter and
gray textured source backdrops remain. Border gate failures and all 11 exceptions are
visible in the inventory rather than silently dropped. Leaf/lesion deletion rates
cannot be calculated without ground-truth masks. The mechanical accepted/error rates
cover the whole dataset; the visual no-obvious-deletion statement covers only its sample.

## FULL-FRAME VS EXTRACTION RECOMMENDATION

**Recommend B: full-frame preprocessing for the first training baseline.** It preserves
visible tissue, behaves consistently across all classes and avoids changing background
only for four Rust contents. Conservative extraction provides negligible background
removal in this corpus; its majority behavior is already full-frame fallback. Neither
policy proves field generalization or eliminates publisher-background shortcuts.

Use the same shared `SegmentationConfig(mode="disabled")` in both consumers if this
recommendation is approved. Version/hash/model manifests must record the selected policy.
Canonical default/config/source were **not changed**. No new segmentation implementation,
model-specific normalization or training-only manual mask was introduced.

## SPLITTING RECOMMENDATION

No official split exists to preserve. For authorized Phase 10, recommend reproducible
**grouped stratified original-content splitting**, not random per-file allocation:

1. Create a future inclusion/exclusion index; leave current files unchanged.
2. Exclude 11 invalid inputs and whole conflicting families pending adjudication/use decisions.
3. Collapse exact/pixel copies; group recovered original-name/UUID identities and visually
   confirmed near/rotated relatives. Keep all derivative members on one side of every split.
4. Use source/capture evidence only where corroborated. Repeated camera IDs/timestamps
   and numbered filenames are not verified plant/session groups.
5. Stratify by literal labels where group counts allow, then record seed, ratios, source
   hashes/group IDs and exclusions. Select ratios after eligibility, not invented counts.
6. Apply random augmentation only to training after splitting. Validation/test and serving
   invoke the same deterministic shared preprocessing. Never tune on test data.

The two archives are overlapping and cannot serve as independent train/test domains.
Plant-independent or deployment-field accuracy cannot be claimed without independent
collection information/external evaluation. No partitions or training seed were created.

## USER DECISIONS REQUIRED

Only questions unresolved by the actual files:

1. **Approve exclusion of the three contradictory families and 11 invalid inputs from
   the future supervised index?** Recommended default: exclude/flag them without source
   deletion or automatic relabeling; expert adjudication only if retaining them matters.
2. **What is the intended permitted dataset/model use?** Public-source declarations and
   embedded notices are recovered, but they do not establish uniform commercial rights.
   Recommended default: use only rights-reviewed material within its terms and hold
   contrary/unclear-rights photographs out until permission is established. The existing
   PlantVillage color subset is identifiable for a limited baseline; a publisher license
   must not override conflicting individual notices blindly.
3. **Approve full-frame shared preprocessing for the first training baseline?** Recommended
   default: disabled extraction in the existing package, recorded identically for serving.

No request for manually supplied labels, splits, source paths, augmentation inventory
or fabricated plant metadata is necessary. Compute/model choices can be handled in
the explicitly authorized training phase; the existing CPU environment works.

## BLOCKERS BEFORE PHASE 10

- Unresolved inclusion/adjudication of contradictory supervised labels and invalid inputs.
- Intended use/permission boundaries for mixed-rights content.
- Approval/recording of one evaluated preprocessing policy for training and serving.

Missing dataset/labels and lack of any real-image review are no longer blockers.
Absence of complete plant/session identity remains an evaluation limitation; use the
recoverable grouping facts and disclose it rather than require invented user metadata.

### Configuration, implementation and checks

`ml-training/configuration.py` provides `load_dataset_path()`: training-local dotenv,
independent of cwd, OS precedence including blank overrides, no interpolation/global
environment mutation, absolute existing-directory validation. `.env.example` has blank
DATASET_PATH. Local path is ignored and must not be copied into scripts or committed docs.
`dataset_inventory.py`/`dataset_review.py` read this loader and call only the shared
preprocessing API. Output must be new/outside source and cannot overwrite existing output.
Final file-list/size/mtime/hash comparison confirms all 8,040 source contents unchanged.

Checks actually performed:

- Training aggregate: Ruff format/lint eight files, strict mypy four source files,
  **29 tests pass** (19 config, five intake, five existing dependency/shared identity).
- Locked sync/check and pip check: **35 installed training distributions compatible**;
  python-dotenv 1.2.4 is the only added dependency; existing versions unchanged.
- Full 8,040 inventory + two shared-policy attempts each; independent count/hash summaries.
- Final 80-image/two-policy real consumer parity: **160 cases pass**.
- Repository structure/template/ignore checks; local links, whitespace, private-path/
  credential checks. No unrelated backend/mobile/database changes or needless rerun.

From repository root:

```powershell
ml-training/.venv/Scripts/python.exe ml-training/dataset_review.py --output .cache/dataset-review/new-local-review
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Training
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1
```

The command accepts output/sample-size settings; the dataset path comes exclusively
from configuration. Output is a development review, not a cached training dataset.

## EXACT NEXT STEP

Review the saved comparisons and approve the three specific inclusion/use/policy
decisions above. No additional label/split/provenance files are requested. Then explicitly
authorize Phase 10 to implement recorded exclusions/grouped splits and training. Phase 9.5
stops here; original files remain intact and no model training has begun.
