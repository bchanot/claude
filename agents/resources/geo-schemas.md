# Schema.org for GEO — types that matter in 2026

All examples use JSON-LD (the only format Google recommends in 2026).
Place inside `<script type="application/ld+json">` in `<head>` or
before `</body>`.

## DEPRECATED — do not emit

Google deprecated these in June 2025. Stop emitting them and remove
existing instances. They no longer produce rich results.

- `ClaimReview` (was a fact-check signal)
- `CourseInfo`
- `EstimatedSalary`
- `LearningVideo`
- `SpecialAnnouncement`
- `VehicleListing`
- `Book` actions (ReadAction, BuyAction on Book)

## TIER 1 — highest GEO impact

### QAPage — single Q&A format

Use when the page is built around ONE primary question. Emitting the type
that matches the content shape beats wrapping everything in a generic
`Article`.

> **No lift figure here — the one that lived here was wrong.** Until
> 2026-07-16 this read "Pages cited 58% more often by ChatGPT vs basic
> Article schema", uncited. Nothing supports it. The nearest real number is
> AccuraCast 2025 (~2,000 prompts across ChatGPT / AI Overviews /
> Perplexity, ~9,000 cited sources): **`Person` schema appeared in 58.9%**
> of cited sources — a *prevalence* count for a *different type* — while
> **`FAQPage` appeared in 1.8%**, which points the opposite way to the claim
> it was propping up. Q&A shape is still worth doing on genuinely
> single-question pages; it is not worth a fabricated number. Do NOT quote a
> QAPage lift % to a client — there isn't one.

```json
{
  "@context": "https://schema.org",
  "@type": "QAPage",
  "mainEntity": {
    "@type": "Question",
    "name": "What is the best framework for a public website in 2026?",
    "text": "Should I use React SPA, Next.js, or Astro for a public-facing website in 2026?",
    "answerCount": 1,
    "acceptedAnswer": {
      "@type": "Answer",
      "text": "For public-facing websites, Astro is the 2026 default because it ships static HTML by default, preserves SEO/GEO signals, and allows React/Vue/Svelte islands only where interactivity is needed. React SPAs are only appropriate for authenticated, non-indexed surfaces.",
      "dateCreated": "2026-04-21",
      "upvoteCount": 0,
      "author": {
        "@type": "Person",
        "name": "Author Name",
        "url": "https://example.com/about"
      }
    }
  }
}
```

### FAQPage — multiple Q&A

Only valid when the page visibly contains all listed questions and
answers. Google will penalise pages with FAQ schema that doesn't match
visible content.

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "How long does shipping take?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Standard shipping takes 2 to 5 business days in France."
      }
    },
    {
      "@type": "Question",
      "name": "Do you offer refunds?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Yes — refunds are available within 30 days of purchase."
      }
    }
  ]
}
```

### Speakable — voice + AI extraction marker

Speakable flags the passage best suited for voice readout and AI summary.

> **No voice-share figure — the one that lived here was a conflation.**
> Until 2026-07-16 this read "62% of searches in 2026 involve voice",
> uncited. No primary source carries it; 62% circulates as a *smart-speaker
> adoption* number, not a share of searches. It is the same family as the
> "50% of searches will be voice by 2020" myth — attributed to ComScore,
> who **denied it**; the real origin is a 2014 Andrew Ng interview. Speakable
> is cheap and harmless, so keep recommending it on TL;DR / summary blocks —
> but justify it by extraction shape, never by a voice-share statistic.

```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Article headline",
  "speakable": {
    "@type": "SpeakableSpecification",
    "cssSelector": [".article-summary", ".tldr"]
  }
}
```

Or via xpath for non-CSS-targetable content:
```json
"speakable": {
  "@type": "SpeakableSpecification",
  "xpath": ["/html/head/title", "//div[@class='tldr']"]
}
```

### Article + Person — E-E-A-T backbone

The single most important pattern for non-local content. Couples
content to a real author with verifiable credentials.

```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Exact title of the article",
  "description": "One-sentence summary matching meta description.",
  "image": ["https://example.com/images/hero-1x1.jpg", "https://example.com/images/hero-4x3.jpg", "https://example.com/images/hero-16x9.jpg"],
  "datePublished": "2026-04-15T09:00:00+02:00",
  "dateModified": "2026-04-21T14:30:00+02:00",
  "author": {
    "@type": "Person",
    "@id": "https://example.com/about#author-jane",
    "name": "Jane Doe",
    "url": "https://example.com/authors/jane-doe",
    "image": "https://example.com/images/jane-doe.jpg",
    "jobTitle": "Senior Plumber",
    "description": "Master plumber with 15 years of experience in Paris region.",
    "knowsAbout": ["plumbing", "boiler repair", "leak detection"],
    "alumniOf": "Lycée Professionnel Diderot",
    "award": ["Qualibat RGE certification", "Artisan de l'année 2024 Essonne"],
    "worksFor": {
      "@type": "Organization",
      "@id": "https://example.com/#org"
    },
    "sameAs": [
      "https://www.linkedin.com/in/jane-doe-plomberie",
      "https://twitter.com/janedoeplumbing",
      "https://www.wikidata.org/wiki/Q123456789"
    ]
  },
  "publisher": {
    "@type": "Organization",
    "@id": "https://example.com/#org",
    "name": "Business Name",
    "logo": {
      "@type": "ImageObject",
      "url": "https://example.com/logo.png"
    }
  },
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://example.com/article-slug"
  }
}
```

## TIER 2 — solid GEO contribution

### HowTo — procedural content

```json
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "How to reset a Chaffoteaux Talia Green boiler",
  "description": "Step-by-step reset procedure for the Talia Green combi boiler.",
  "totalTime": "PT5M",
  "estimatedCost": {"@type": "MonetaryAmount", "currency": "EUR", "value": "0"},
  "tool": [{"@type": "HowToTool", "name": "None"}],
  "step": [
    {
      "@type": "HowToStep",
      "name": "Locate the reset button",
      "text": "The reset button is on the front panel, marked with a flame icon.",
      "url": "https://example.com/guides/reset#step1",
      "image": "https://example.com/img/step1.jpg"
    },
    {
      "@type": "HowToStep",
      "name": "Press and hold for 3 seconds",
      "text": "Press the reset button until the red light turns off.",
      "url": "https://example.com/guides/reset#step2"
    }
  ]
}
```

### BreadcrumbList — navigation context for AI

Gives AI the hierarchical position of the page. Nearly universal to
add, low cost.

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {"@type": "ListItem", "position": 1, "name": "Accueil", "item": "https://example.com/"},
    {"@type": "ListItem", "position": 2, "name": "Services", "item": "https://example.com/services"},
    {"@type": "ListItem", "position": 3, "name": "Dépannage chaudière", "item": "https://example.com/services/depannage-chaudiere"}
  ]
}
```

### LocalBusiness — local services (required for local SEO)

Must be consistent with GMB. Any divergence is a NAP inconsistency.

```json
{
  "@context": "https://schema.org",
  "@type": "Plumber",
  "@id": "https://example.com/#business",
  "name": "Plomberie Dupont",
  "image": "https://example.com/img/shopfront.jpg",
  "url": "https://example.com",
  "telephone": "+33123456789",
  "priceRange": "€€",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "12 rue des Lilas",
    "addressLocality": "Évry-Courcouronnes",
    "postalCode": "91000",
    "addressRegion": "Île-de-France",
    "addressCountry": "FR"
  },
  "geo": {
    "@type": "GeoCoordinates",
    "latitude": 48.62939,
    "longitude": 2.44199
  },
  "openingHoursSpecification": [
    {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
      "opens": "08:00",
      "closes": "18:00"
    }
  ],
  "areaServed": [
    {"@type": "City", "name": "Évry-Courcouronnes"},
    {"@type": "City", "name": "Corbeil-Essonnes"},
    {"@type": "AdministrativeArea", "name": "Essonne"}
  ],
  "sameAs": [
    "https://www.facebook.com/plomberiedupont",
    "https://www.instagram.com/plomberiedupont",
    "https://www.pagesjaunes.fr/pros/12345",
    "https://www.wikidata.org/wiki/Q999999999"
  ]
}
```

Use the most specific subclass of `LocalBusiness` available (`Plumber`,
`Dentist`, `Restaurant`, `AutoRepair`, etc.) — list at
https://schema.org/LocalBusiness under "More specific Types".

### Organization — company-level entity

Separate from `LocalBusiness` when brand > single location.

```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "@id": "https://example.com/#org",
  "name": "Company Name",
  "legalName": "Company Name SAS",
  "url": "https://example.com",
  "logo": "https://example.com/logo.png",
  "foundingDate": "2015-03-01",
  "founders": [{"@type": "Person", "name": "Founder Name"}],
  "numberOfEmployees": {"@type": "QuantitativeValue", "value": "12"},
  "vatID": "FR12345678901",
  "iso6523Code": "0199:123456789",
  "sameAs": [
    "https://www.wikidata.org/wiki/Q123456",
    "https://www.linkedin.com/company/companyname",
    "https://www.crunchbase.com/organization/companyname"
  ],
  "contactPoint": {
    "@type": "ContactPoint",
    "telephone": "+33123456789",
    "contactType": "customer service",
    "availableLanguage": ["fr", "en"]
  }
}
```

### Dataset — factual reference content

Use for data-heavy pages (statistics, research, public-data reports).

```json
{
  "@context": "https://schema.org",
  "@type": "Dataset",
  "name": "French boiler energy consumption by model, 2020-2025",
  "description": "Average annual kWh consumption for 47 boiler models installed in France.",
  "license": "https://creativecommons.org/licenses/by/4.0/",
  "creator": {"@type": "Organization", "@id": "https://example.com/#org"},
  "distribution": {
    "@type": "DataDownload",
    "encodingFormat": "text/csv",
    "contentUrl": "https://example.com/data/boilers-2020-2025.csv"
  }
}
```

## TIER 3 — niche but high-leverage when applicable

- **`Product`** — e-commerce (required for Merchant Center)
- **`Recipe`** — food sites
- **`Event`** — event listings
- **`JobPosting`** — job boards
- **`Review` / `AggregateRating`** — only when backed by verifiable public reviews (fraud risk otherwise)
- **`VideoObject`** — any embedded video (transcripts are critical for AI)
- **`DefinedTerm` / `DefinedTermSet`** — glossary pages, taxonomy (great for entity disambiguation)
- **`Course` / `EducationalOccupationalCredential`** — training/cert providers
- **`MedicalBusiness`, `PhysiologicalFeature`, `Drug`** — health (YMYL, demand extra rigour)

## Graph linking — @id patterns

Use `@id` to build a single graph across multiple JSON-LD blocks:

```json
{"@context":"https://schema.org","@graph":[
  {"@type":"Organization","@id":"https://example.com/#org","name":"..."},
  {"@type":"WebSite","@id":"https://example.com/#website","publisher":{"@id":"https://example.com/#org"}},
  {"@type":"WebPage","@id":"https://example.com/page#webpage","isPartOf":{"@id":"https://example.com/#website"}},
  {"@type":"Article","mainEntityOfPage":{"@id":"https://example.com/page#webpage"},"author":{"@id":"https://example.com/about#author-jane"}}
]}
```

This is the pattern Yoast, RankMath, and modern headless-CMS plugins
output. It lets AI engines traverse entities without duplicating them.

## Validation

- https://validator.schema.org — strict Schema.org validator
- https://search.google.com/test/rich-results — Google Rich Results Test
- https://developers.google.com/search/docs/appearance/structured-data — type-by-type Google docs
