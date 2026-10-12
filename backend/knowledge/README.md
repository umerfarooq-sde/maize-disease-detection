# Curated maize knowledge corpus

Version `maize-extension-20261012-v1` contains four literal classifier labels and 25 independently worded, short English knowledge documents. The corpus is intentionally curated from the four university extension pages below. It is general educational evidence for research/FYP retrieval, not a field-health certificate or a local pesticide prescription.

| Label | Reviewed source | Coverage |
| --- | --- | --- |
| Common_Rust | [Common rust on corn](https://extension.umn.edu/agriculture/crop-production/corn/common-rust-on-corn), University of Minnesota Extension, Dean Malvick; reviewed 2018 | Overview, symptoms, causes, conditions, management, prevention, references |
| Gray_Leaf_Spot | [Gray leaf spot on corn](https://extension.umn.edu/agriculture/crop-production/corn/gray-leaf-spot-on-corn), University of Minnesota Extension, Dean Malvick; reviewed 2018 | All seven disease topics |
| Northern_Corn_Leaf_Blight | [Northern corn leaf blight](https://extension.umn.edu/agriculture/crop-production/corn/northern-corn-leaf-blight), University of Minnesota Extension, Dean Malvick; reviewed 2018 | All seven disease topics |
| Healthy | [Early Season Crop Scouting](https://crops.extension.iastate.edu/encyclopedia/early-season-crop-scouting), Iowa State University Extension and Outreach, Meaghan Anderson, Angie Rieck-Hinz and Rebecca Vittetoe; reviewed 2026-05-11 | Overview, symptoms as scouting concerns, prevention as scouting context, references |

All URLs were inspected through browser retrieval on 2026-10-12. Publication dates were not identified and remain `null`; review dates are separate metadata and are not invented publication dates. Each document retains a section-specific reference, source URL, publisher, authors, review context, retrieval date, rights statement and region.

Healthy is a classifier label rather than a disease entity. No sourced Healthy cause, disease-favoring conditions or treatment is present; these sections must return an honest empty/insufficient-evidence result. The scouting source concerns early-season maize and soybean field assessment. This corpus retains only relevant maize context and does not turn its seedling observations into a mature-leaf diagnosis.

## Source and rights boundaries

The Minnesota pages display copyright/all-rights-reserved notices. The Iowa page carries its university copyright notice. Public availability is not an open licence. This repository retains concise independently authored factual paraphrases and citation metadata, without source photographs, figures, full articles or raw HTML. It makes no assertion of permission to redistribute publisher material or of commercial clearance; broader reuse needs a rights review.

These sources concern U.S. regions. Climate, hybrids, pathogen populations, conservation practices and registered products can differ elsewhere. The corpus contains no product names, dose rates, spray schedules, yield guarantees or region-specific regulatory claims. Management options require local agronomic assessment. The three Minnesota pages' 2018 review dates are a freshness limitation; intentional future updates require another reviewed document/corpus version.

## Version and review identity

`maize-extension-20261012-v1.json` is the reviewed source input; ingestion should never fetch arbitrary URLs, invent missing sections or mutate an existing version payload. `maize-extension-20261012-v1.review.json` pins canonical corpus, source-provenance and individual UTF-8 content hashes. The review is an intentional engineering curation from the named authoritative publishers; it is not a claim that those publishers endorsed MAIZEDOCTOR or that an independent agronomist approved the application.

Canonical JSON hashing recursively sorts object keys, preserves array order, uses UTF-8 without escaping non-ASCII characters, and serializes compactly with comma/colon separators and no trailing newline. Document content hashing uses exact UTF-8 content bytes. Source-provenance hashes cover the canonical source metadata, not publisher file bytes. Direct publisher HTTP retrieval was unavailable from the workstation; no source-file SHA is fabricated and no publisher page is archived. A source page can change while its retained citation/review identity remains fixed.

Keep this version and ledger unchanged after import/commit. Corrections or changed facts require a new version and a documented review. Generated embeddings, retrieval settings, document/chunk identity and index publication belong to the controlled ingestion workflow.

## Retrieval evaluation

[rag-v1.json](../../ai-service/evaluation/rag-v1.json) has 16 positive development cases, four per label, and three explicit unavailable Healthy topic cases. Each positive identifies the precise expected document key; each negative requires empty evidence after the same class/topic filters. These curated queries test relevance and source filtering, not independent field accuracy or answer-generation faithfulness. Phase 14 does not generate agricultural answers. Provider embeddings are a semantic representation of retained evidence, not a new agricultural source.

Adversarial text, out-of-domain requests, provider failures, archived documents, malformed vectors and inactive/draft filtering still require application contract tests; the small reviewed query set does not replace them.
