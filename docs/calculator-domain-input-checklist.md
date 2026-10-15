# Calculator domain content — review checklist

Phase 23.7 verifies the existing deterministic frameworks without inventing data.
Real public catalogues remain `PENDING_RULES` (fertilizer) and
`PENDING_CONFIGURATION` (yield). This does not block private farmer profiles.

You may supply an authoritative source document/link and approve its applicability;
you do not need to hand-write JSON or reverse-engineer existing schemas. Codex can
extract candidate fields and prepare a reviewable draft in separately authorized work.
No provider key, dataset label or ML retraining is required for this content task.

## Fertilizer approval/data needed

- [ ] Identify the intended maize context: region, crop/growth stage and relevant
  soil/recommendation conditions **only where the source actually requires them**.
- [ ] Provide or approve a source-backed fertilizer product and label: name/description,
  N, P₂O₅ and K₂O percentages with explicit units/basis, application method and
  relevant precautions. Oxide percentages are not interchangeable with elemental P/K.
- [ ] Approve the product mass rate in **kg of that product per hectare**, its source
  justification, applicability and assumptions. The current engine scales an approved
  product rate; it does not infer soil nutrient requirements or choose an agronomic dose.
- [ ] Supply title, publisher, stable HTTPS source URL, citation/document section,
  publication/review date where available and reuse rights. Distinguish product-label
  composition from the agronomic source recommending its rate.
- [ ] Approve the reviewed rule/configuration version and output precision. Current
  input area units are hectare/international acre and result units kg/grams. No
  unspecified local area unit or unapproved application timing is inferred.

Original ambitions such as N/P/K need assessment, dosing schedules or soil-based
selection require an authoritative model and explicit implementation if the current
product-rate template cannot represent them. Never fill these gaps with Gemini or
synthetic fixture rates.

## Yield configuration approval/data needed

- [ ] Identify the intended region/maize production context and define what the
  estimate represents (for example a reviewed historical/reference scenario).
- [ ] Provide or approve the agronomic source/model and its applicable expected
  **kg per hectare** value. The implemented template is area × reviewed kg/ha; it
  is a conditional planning projection, not a validated field forecast.
- [ ] Specify justified applicability, assumptions and relevant limitations. Do not
  add plant density, weather, irrigation, disease-loss or moisture coefficients unless
  an approved model actually defines and supports them.
- [ ] Retain source title, publisher, HTTPS URL, citation/section, known dates,
  rights and reviewer approval. State whether the value is reported/derived and
  preserve its original units and derivation.
- [ ] Approve the immutable configuration version, result precision and selected
  kg/metric-tonne presentation. Current area units are hectare/international acre.

A different agronomic formula or min/expected/potential forecast range needs a
separate reviewed/versioned engine change; arbitrary formula text is not executed.
Operational numeric bounds in Zod are not evidence that an agronomic rate is plausible.

## Approval and publication process

1. Review authoritative evidence, rights and local applicability; identify an
   authorized project/domain reviewer. Codex can prepare candidates, not invent approval.
2. Extract exact supported quantities/units/assumptions and retain source references.
   Record uncertainties or unsupported requirements instead of substituting values.
3. Use the existing Admin management forms to create an immutable **inactive DRAFT**.
   The server stamps reviewer identity/time and records the creation audit.
4. Compare deterministic outputs, conversions and rounding with source-backed
   worked cases. Gemini must never calculate or modify the quantities.
5. Explicitly approve/activate the reviewed version. The backend audits publication
   and retires the previous active version without rewriting historical payloads.
6. If evidence/applicability changes, create and review a new version. Do not edit
   an active immutable rule or enable a synthetic test fixture as real content.

See [fertilizer contracts](33-fertilizer-calculator.md),
[yield contracts](34-expected-yield-calculator.md) and
[Admin management](37-admin-management.md). Research/demo use does not establish
commercial licensing or safety for unreviewed local field recommendations.
