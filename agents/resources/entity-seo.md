# Entity SEO — Wikidata, Knowledge Graph, sameAs

Why this matters: every major AI engine (ChatGPT, Claude, Gemini,
Perplexity, Apple Intelligence) grounds factual claims against
Wikidata. A business without a clean entity footprint is effectively
invisible to AI grounding pipelines, regardless of on-site SEO.

## The entity identity stack

Think of your entity as having five layers, from strongest to weakest
identity signal:

1. **Wikidata QID** — globally unique, machine-readable identifier.
2. **Wikipedia article** — human-readable notability signal.
3. **Google Knowledge Panel** — surfaced directly in Google results.
4. **Authoritative third-party IDs** — Crunchbase, Bloomberg, SIRENE (FR), Companies House (UK), OpenCorporates.
5. **Social + directory profiles** — LinkedIn, Facebook, PagesJaunes, industry directories.

Each layer reinforces the ones below. Wikidata is the most leveraged
because it's structured, open, and explicitly consumed by LLMs.

## Audit checklist

### Does the entity have a Wikidata QID?

Search: https://www.wikidata.org/wiki/Special:Search — by name + city.

If found:
- Record QID (format `Q` + number, e.g. `Q12345678`)
- Verify: official website property (P856) points to the current domain
- Verify: VAT (P3608), SIRET (P3893), category (P31) are correct

If NOT found:
- For businesses meeting Wikidata notability: creation is possible
  (requires verifiable third-party sources)
- For non-notable businesses: skip Wikidata, focus on other identity layers
- Flag in SEO.md §11 as user action (Wikidata requires human judgement
  + source citations)

### Does the entity have a Wikipedia article?

- Search by exact business name. If found and matches: record URL.
- If not found: flag as long-term goal (long-term — notability bar is high).

### Is there a Google Knowledge Panel?

Search Google: exact business name. Look for the right-side panel.

- Present + claimed → verify info is correct
- Present + unclaimed → user action: claim via https://www.google.com/business/
- Absent → Knowledge Panels are generated automatically when entity
  signals are strong enough (GMB + Wikidata + consistent citations)

### Is `sameAs` complete in on-site JSON-LD?

The `sameAs` property is how you declare "these external URLs represent
the same entity as this page". It's the single most impactful entity
signal after Wikidata.

Minimum recommended `sameAs` for a local business:
```json
"sameAs": [
  "https://www.wikidata.org/wiki/Q123456789",  // if exists
  "https://www.linkedin.com/company/name",
  "https://www.facebook.com/businessname",
  "https://www.instagram.com/businessname",
  "https://www.pagesjaunes.fr/pros/12345",     // FR
  "https://fr.wikipedia.org/wiki/Nom_Entreprise" // if exists
]
```

For a SaaS / international brand, add:
```json
"https://www.crunchbase.com/organization/name",
"https://github.com/organization",
"https://www.g2.com/products/name",
"https://www.producthunt.com/products/name"
```

For a Person (author, founder):
```json
"sameAs": [
  "https://www.wikidata.org/wiki/Q987654321",
  "https://www.linkedin.com/in/name",
  "https://twitter.com/name",
  "https://github.com/name",
  "https://scholar.google.com/citations?user=XYZ", // academics
  "https://orcid.org/0000-0000-0000-0000"          // academics
]
```

### Is `@id` used consistently?

Across all JSON-LD blocks on the site, the same entity MUST use the
same `@id`. Pattern: `https://example.com/#org` for the organization,
`https://example.com/about#author-{slug}` for people.

Split across multiple pages? Use `@id` with fragment identifiers to
tie them back to one canonical entity node.

## The Wikidata playbook for businesses

Not every business qualifies for Wikidata. Criteria (simplified):
- Multiple independent third-party sources (press articles, books,
  academic papers) covering the entity.
- Some form of public notability (not just "we exist").

If qualified, the creation workflow:

1. Create Wikidata account.
2. Use "Create a new item" → name, label, description.
3. Add statements with sources:
   - `instance of (P31)` → `enterprise (Q6881511)` or more specific
   - `country (P17)` → `France (Q142)`
   - `headquarters location (P159)` → city QID
   - `official website (P856)` → domain URL
   - `inception (P571)` → founding date
   - `industry (P452)` → industry QID
   - `SIRET (P3893)` → SIRET number (FR)
   - `VAT number (P3608)` → VAT ID
4. Each statement must cite a reference (URL of press article,
   official registry, etc.).
5. Wait for community review. Items without sources get merged or deleted.

This is labor-intensive and failure-prone for non-notable entities.
Do NOT invent sources. Better to skip Wikidata than create a deletable item.

## Automation options (for SEO.md §11)

- **Kalicube** — paid service specialised in Knowledge Panel + Wikidata
  optimization for businesses and executives.
- **Entity.ai** / **InLinks** — tools that help structure entity
  signals on-site + track Knowledge Panel status.
- **WordLift** — WordPress/plugin with Wikidata linking + Schema.org
  graph generation.
- **Yext Knowledge Graph** — enterprise platform syncing entity data
  across 200+ directories.
- **BrightLocal / Moz Local / Uberall** — focus on local citations
  + directory sync (not Wikidata-specific).

For Wikidata specifically: no full-automation tool is reliable because
it requires sourced statements. Human curation is the bottleneck.

## Common mistakes

- **Fake Wikidata entries** — flagged and deleted by community, damages
  reputation.
- **`sameAs` pointing to dead profiles** — validate each URL resolves.
- **Inconsistent entity names across platforms** ("Dupont Plomberie"
  vs "Plomberie Dupont" vs "DUPONT PLOMBERIE SAS") — pick one, apply
  everywhere.
- **Missing VAT/SIREN on Organization schema** — easy credibility
  signal, often forgotten.
- **Treating @id as a URL that must resolve** — `@id` is an identifier,
  not a mandatory-resolvable URL (though resolvable is better).

## Verification tools

- https://www.wikidata.org/wiki/Special:Search — find QID
- https://tools.wmflabs.org/reasonator/ — human-readable Wikidata view
- https://kalicube.com — commercial Knowledge Panel audit
- https://www.google.com/search?q=%22business+name%22 — check Knowledge Panel
- Schema validator (see `geo-schemas.md`) — check `@id` + `sameAs` integrity
