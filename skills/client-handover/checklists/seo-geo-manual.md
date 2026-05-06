# SEO/GEO Manual Checklist — Resource for client-handover

This file is read by `client-handover-writer.md` to populate the SEO/GEO
chapter of the client handover document. It contains the canonical
platform list, registration URLs, and pre-written client-facing copy in
both French and English.

The agent picks the right section based on:
- `LANG` = `fr` | `en`
- `IS_LOCAL_BUSINESS` = `true` | `false`

**Maintenance**: when adding a platform, add the row in BOTH the FR and
EN tables, AND update the `Platform reference` fallback in
`~/.claude/agents/client-handover-writer.md`. Verify URLs are still
current (re-check yearly).

URL sanity: the agent should run `WebFetch` on a sample of these URLs
when first using the chapter to confirm they're alive. Replace any
dead link via `WebSearch` for the platform's current signup page.

---

# SECTION A — Local business, FRENCH

Insert verbatim (translate placeholders) into the deliverable when
`LANG=fr` AND `IS_LOCAL_BUSINESS=true`.

## 8. Améliorer votre visibilité en ligne — ce qui dépend de vous

### Pourquoi ce chapitre

Votre site est maintenant en ligne et techniquement bien construit. Mais
être visible sur Google, sur ChatGPT, ou dans les annuaires comme Pages
Jaunes, dépend ensuite d'un travail manuel que **seul vous pouvez faire**.
On ne peut pas créer une fiche Google à votre place — il faut une preuve
d'identité (photo, courrier postal, numéro vérifié). Voici la liste
complète des actions qui feront réellement progresser votre visibilité.

Ces actions prennent 2 à 4 heures au total. Faites-les dans l'ordre.

### Étape 1 — Définir vos informations officielles (15 min)

C'est l'étape **la plus importante**. Le moindre écart entre les
plateformes (un espace en trop, un "0" devant le numéro, une virgule
manquante dans l'adresse) divise votre visibilité Google.

Choisissez UNE seule version officielle de chaque champ et utilisez-la
**à l'identique partout** :

| Champ          | Valeur officielle à utiliser partout                       |
|----------------|------------------------------------------------------------|
| Nom commercial | [À COMPLÉTER — exactement comme sur le Kbis]              |
| Adresse        | [À COMPLÉTER — n° rue, code postal, ville]                |
| Téléphone      | [À COMPLÉTER — format: +33 X XX XX XX XX]                |
| Email pro      | [À COMPLÉTER]                                             |
| Site web       | [À COMPLÉTER — avec le https://]                          |
| Horaires       | [À COMPLÉTER — ligne par jour, format 24h: 09:00–18:00]   |
| Catégorie      | [À COMPLÉTER — la principale, ex: "Restaurant italien"]   |

Notez ces informations dans un fichier que vous gardez à portée de main —
vous allez les recopier 10 fois.

### Étape 2 — Plateformes prioritaires (à faire la première semaine)

**Google Business Profile** — la plus importante. C'est ce qui s'affiche
quand on cherche votre nom sur Google ou Google Maps.
- Inscription : https://www.google.com/business/
- À faire : créer la fiche, vérifier (Google envoie un code par courrier
  postal — 5 jours), ajouter au moins 10 photos (intérieur, extérieur,
  équipe, produits), remplir tous les champs.
- ☐ Fiche créée
- ☐ Vérification reçue et validée
- ☐ 10 photos minimum
- ☐ Description rédigée (200 caractères, contient votre activité + ville)
- ☐ Horaires complets (et horaires spéciaux pour les jours fériés)

**Pages Jaunes** — toujours très utilisé en France, surtout par les 50+.
- Inscription : https://www.pagesjaunes.fr/pro/inscription
- ☐ Fiche créée
- ☐ Photo de couverture
- ☐ Description

**Apple Business Connect** — pour apparaître sur Plans (iPhone, Mac).
- Inscription : https://businessconnect.apple.com/
- ☐ Fiche créée
- ☐ Validation faite

**Bing Places** — moins de trafic mais c'est aussi ce qui alimente
ChatGPT (Bing est le moteur derrière les recherches IA de Microsoft).
- Inscription : https://www.bingplaces.com/
- Astuce : importez directement depuis Google Business Profile pour
  gagner du temps.
- ☐ Fiche créée

### Étape 3 — Réseaux sociaux et avis (à faire le premier mois)

**Facebook Page** — toujours utile, surtout pour les avis.
- Inscription : https://www.facebook.com/pages/create
- ☐ Page créée avec les mêmes infos NAP (voir Étape 1)
- ☐ Photo de profil + photo de couverture
- ☐ Bouton "Contact" ou "Réserver" configuré

**Instagram Business** — visuel, idéal pour montrer votre travail.
- Inscription : https://business.instagram.com/
- À faire : convertir en compte pro, lier à la page Facebook.
- ☐ Compte pro activé
- ☐ Bio avec lien vers le site
- ☐ Premier post avec hashtag local (#[votreville])

**TikTok Business** — si votre activité s'y prête (visuel, créatif,
jeune public).
- Inscription : https://www.tiktok.com/business/
- ☐ Compte créé (optionnel, à évaluer selon votre activité)

**Yelp** — moins utilisé en France qu'aux US mais référencé par Apple
Plans et Siri.
- Inscription : https://biz.yelp.com/
- ☐ Fiche créée

### Étape 4 — Cartographie et géolocalisation

**Mappy** — concurrent de Google Maps en France.
- Inscription : https://corporate.mappy.com/
- ☐ Fiche créée

**Waze** — racheté par Google, moins critique mais utile.
- Inscription via Google Business Profile (c'est lié).
- ☐ Adresse vérifiée sur Waze

### Étape 5 — Plateformes selon votre activité

À ajouter UNIQUEMENT si pertinent pour votre métier :

| Métier              | Plateforme                              | Lien |
|---------------------|------------------------------------------|------|
| Restaurant          | TheFork (La Fourchette)                  | https://www.thefork.com/restaurant |
| Restaurant / Hôtel  | TripAdvisor                              | https://www.tripadvisor.fr/Owners |
| Hôtel / Location    | Booking.com                              | https://join.booking.com/ |
| Locations courtes   | Airbnb                                   | https://www.airbnb.fr/host/homes |
| Médecin / paramédical | Doctolib                              | https://pro.doctolib.fr/ |
| Beauté / coiffure   | Planity / Treatwell                      | https://www.planity.com/pro |
| Artisan / services  | Stootie / AlloVoisins                    | https://www.allovoisins.com/ |
| B2B / pro           | LinkedIn Company Page                    | https://www.linkedin.com/company/setup/new/ |
| Boutique en ligne   | Trustpilot                               | https://business.trustpilot.com/ |
| Avocat              | Avocat.fr / Justifit                     | https://www.justifit.fr/inscription/ |

### Étape 6 — Annuaires généralistes (gain marginal mais cumulatif)

À faire en bloc, après les étapes 1-5 :
- Justacote — https://www.justacote.com/
- Hoodspot — https://www.hoodspot.fr/
- Foursquare — https://business.foursquare.com/
- Le Bottin — https://www.lebottin.fr/

### Étape 7 — Visibilité sur les IA (ChatGPT, Claude, Perplexity, Gemini)

Les moteurs de recherche IA citent maintenant les entreprises dans leurs
réponses. Pour qu'ils parlent de vous correctement :

**Test en direct** (à faire vous-même) :
1. Allez sur https://chat.openai.com/, demandez : "Quels sont les bons
   [votre activité] à [votre ville] ?"
2. Faites pareil sur https://www.perplexity.ai/, https://claude.ai/,
   https://gemini.google.com/
3. Notez ce qui apparaît. Si votre nom n'apparaît pas, c'est attendu
   au début — il faut 2 à 4 mois pour que les IA vous indexent une fois
   les fiches créées.

**Action côté technique** (déjà en place sur votre site) : le développeur
a inclus les balises Schema.org / JSON-LD qui aident les IA à comprendre
votre activité. Vérifiez que ces données sont bien lues :
- Outil : https://search.google.com/test/rich-results
- Collez votre URL et confirmez qu'il n'y a pas d'erreur.

**Wikidata** (optionnel mais puissant si vous êtes une entreprise
établie) : créer une fiche Wikidata fait apparaître votre entreprise
dans le "Knowledge Panel" Google et donne un signal fort aux IA.
- https://www.wikidata.org/wiki/Special:CreateAccount
- Réservé aux entreprises ayant déjà une présence (presse, Wikipédia,
  notoriété). Si ce n'est pas le cas, sautez cette étape.

### Étape 8 — Avis clients (le facteur multiplicateur)

Les avis Google et Facebook sont **le levier #1** pour monter dans les
résultats locaux. Plus vous avez d'avis (positifs et récents), plus
Google vous remonte.

**Méthode simple** :
1. Identifiez 10 clients récents satisfaits.
2. Envoyez-leur ce message (à adapter) :

> Bonjour [Prénom],
> Merci de votre confiance ! Si vous avez 30 secondes, votre avis
> Google nous aiderait beaucoup à nous faire connaître :
> [LIEN GOOGLE — récupéré depuis votre fiche Google Business Profile,
>  section "Demander des avis"]
> Merci pour votre soutien.

3. Visez 5 nouveaux avis le premier mois, puis 1 par semaine.
4. Répondez à **tous** les avis, même les positifs (Google le valorise).

### Étape 9 — Calendrier suggéré

| Quand              | Action |
|--------------------|--------|
| Semaine 1          | Étapes 1, 2 (Google Business, Pages Jaunes, Apple, Bing), Étape 8 (premier message à 5 clients) |
| Semaine 2          | Étape 3 (Facebook, Instagram), Étape 4 (Mappy) |
| Semaine 3-4        | Étape 5 (plateformes métier), Étape 6 (annuaires) |
| Mois 2             | Étape 8 continue (5 avis de plus), Étape 7 (test IA) |
| Mois 3             | Audit complet — cherchez votre nom sur Google + ChatGPT + Pages Jaunes. Tout est-il à jour ? |
| Trimestriel        | Mettre à jour photos, publier 1 post Google Business, vérifier les nouveaux avis |
| Annuel             | Vérifier que les liens des fiches fonctionnent toujours, mettre à jour horaires (vacances, jours fériés) |

### Étape 10 — Outils gratuits pour suivre votre progression

- **Google Search Console** — voir comment Google voit votre site :
  https://search.google.com/search-console
- **Google Business Insights** — accessible depuis votre fiche Google
  Business Profile, montre les recherches qui mènent à vous.
- **BrightLocal Free Tools** — vérifier la cohérence de votre NAP sur
  les annuaires : https://www.brightlocal.com/free-local-tools/
- **PageSpeed Insights** — vérifier que le site reste rapide :
  https://pagespeed.web.dev/

### Erreurs courantes à éviter

- ❌ Mettre des informations différentes sur Pages Jaunes et Google.
- ❌ Oublier de répondre aux avis (négatifs ET positifs).
- ❌ Mettre des photos floues ou prises au flash.
- ❌ Ne pas mettre à jour les horaires pour les jours fériés.
- ❌ Acheter des avis (Google détecte et déclasse).
- ❌ Créer plusieurs fiches Google pour le même établissement (Google
  pénalise les doublons).
- ❌ Utiliser un numéro de téléphone différent du Kbis.

---

# SECTION B — Local business, ENGLISH

Insert verbatim into the deliverable when `LANG=en` AND
`IS_LOCAL_BUSINESS=true`.

## 8. Improving Your Online Visibility — What's On You

### Why this chapter exists

Your site is now live and technically optimized. But being visible on
Google, ChatGPT, or directories like Yelp depends on manual work **only
you can do**. We can't create a Google Business Profile for you — it
needs identity proof (photo, postal verification, phone). Below is the
complete list of actions that will actually move the needle.

These actions take 2-4 hours total. Do them in order.

### Step 1 — Define your official information (15 min)

This is **the most important step**. Any difference between platforms (a
trailing space, a missing comma, a different phone format) splits your
Google visibility.

Pick ONE official version of each field and use it **identically
everywhere**:

| Field            | Official value to use everywhere                |
|------------------|--------------------------------------------------|
| Business name    | [TO FILL — exactly as registered]               |
| Address          | [TO FILL — street, city, ZIP, country]          |
| Phone            | [TO FILL — format: +1 XXX XXX XXXX]             |
| Pro email        | [TO FILL]                                       |
| Website          | [TO FILL — with https://]                       |
| Hours            | [TO FILL — per day, 24h format: 09:00-18:00]    |
| Primary category | [TO FILL — e.g., "Italian restaurant"]          |

Save these in a file you can reach in two clicks. You will copy them 10
times.

### Step 2 — Priority platforms (week 1)

**Google Business Profile** — by far the most important. It's what shows
up when someone searches your name on Google or Maps.
- Sign up: https://www.google.com/business/
- Tasks: create profile, verify (Google sends a postal code — 5 days),
  add 10+ photos (interior, exterior, team, products), fill every field.
- ☐ Profile created
- ☐ Verification received and validated
- ☐ 10+ photos uploaded
- ☐ Description written (200 chars, contains business + city)
- ☐ Full hours (and special holiday hours)

**Apple Business Connect** — to appear on Apple Maps (iPhone, Mac).
- Sign up: https://businessconnect.apple.com/
- ☐ Profile created
- ☐ Validation done

**Bing Places** — lower traffic, but Bing also feeds ChatGPT (Microsoft's
AI search runs on it).
- Sign up: https://www.bingplaces.com/
- Tip: import directly from Google Business Profile to save time.
- ☐ Profile created

**Yelp** — strong in the US, weaker in EU. Powers Apple Maps and Siri.
- Sign up: https://biz.yelp.com/
- ☐ Profile created

### Step 3 — Social and reviews (month 1)

**Facebook Page** — still relevant, especially for reviews.
- Sign up: https://www.facebook.com/pages/create
- ☐ Page created with same NAP (see Step 1)
- ☐ Profile photo + cover photo
- ☐ "Contact" or "Book" button configured

**Instagram Business** — visual, ideal for showcasing work.
- Sign up: https://business.instagram.com/
- Tasks: switch to business account, link to Facebook page.
- ☐ Business account active
- ☐ Bio with website link
- ☐ First post with local hashtag (#[yourcity])

**TikTok Business** — if your business is visual, creative, or appeals
to younger audiences.
- Sign up: https://www.tiktok.com/business/
- ☐ Account created (optional — depends on your industry)

### Step 4 — Maps and geolocation

**Google Maps** — already covered by Google Business Profile.

**Waze** — owned by Google, less critical but still useful.
- Linked through Google Business Profile.
- ☐ Address verified on Waze

**Foursquare for Business** — feeds many third-party apps.
- Sign up: https://business.foursquare.com/
- ☐ Profile created

### Step 5 — Industry-specific platforms

Add ONLY if relevant to your business:

| Industry                 | Platform                       | URL |
|--------------------------|--------------------------------|-----|
| Restaurant               | TripAdvisor                    | https://www.tripadvisor.com/Owners |
| Restaurant (US)          | OpenTable / Resy               | https://restaurant.opentable.com/ |
| Hotel / lodging          | Booking.com                    | https://join.booking.com/ |
| Short-term rental        | Airbnb                         | https://www.airbnb.com/host/homes |
| Medical / health         | Healthgrades / Zocdoc          | https://www.zocdoc.com/ |
| Beauty / wellness        | Mindbody / Vagaro              | https://www.mindbodyonline.com/ |
| Trades / services        | Angi / Thumbtack / TaskRabbit  | https://www.angi.com/ |
| B2B / professional       | LinkedIn Company Page          | https://www.linkedin.com/company/setup/new/ |
| E-commerce / shop        | Trustpilot                     | https://business.trustpilot.com/ |
| Lawyer                   | Avvo / FindLaw                 | https://www.avvo.com/claim-profile |

### Step 6 — General directories (marginal but cumulative gains)

Do these in batch after steps 1-5:
- Better Business Bureau — https://www.bbb.org/
- Hotfrog — https://www.hotfrog.com/
- MerchantCircle — https://www.merchantcircle.com/
- Manta — https://www.manta.com/
- Yellow Pages (US) — https://www.yellowpages.com/

### Step 7 — AI search visibility (ChatGPT, Claude, Perplexity, Gemini)

AI search engines now cite businesses in their answers. To make them
talk about you correctly:

**Live test** (do this yourself):
1. Go to https://chat.openai.com/, ask: "What are good [your business
   type] in [your city]?"
2. Repeat on https://www.perplexity.ai/, https://claude.ai/,
   https://gemini.google.com/
3. Note what appears. If your name isn't there, that's expected at first
   — AI engines need 2-4 months to index you after profiles are live.

**Technical side** (already in place on your site): the developer
included Schema.org / JSON-LD markup that helps AI engines understand
your business. Verify it parses cleanly:
- Tool: https://search.google.com/test/rich-results
- Paste your URL, confirm no errors.

**Wikidata** (optional, powerful for established businesses): a Wikidata
entry boosts Google's Knowledge Panel and gives a strong signal to AI.
- https://www.wikidata.org/wiki/Special:CreateAccount
- Only relevant if your business already has press, a Wikipedia entry,
  or known reputation. Otherwise skip.

### Step 8 — Customer reviews (the multiplier)

Google and Yelp reviews are **the #1 lever** for ranking in local
results. More reviews (positive AND recent) = higher Google ranking.

**Simple method**:
1. Identify 10 recent satisfied customers.
2. Send them this message (adapt):

> Hi [First name],
> Thanks for choosing us! If you have 30 seconds, a Google review would
> mean a lot:
> [GOOGLE LINK — get from your Google Business Profile, "Ask for
>  reviews" section]
> Thanks for the support.

3. Aim for 5 new reviews in month 1, then 1 per week.
4. Reply to **every** review, including positive ones (Google rewards it).

### Step 9 — Suggested timeline

| When           | Action |
|----------------|--------|
| Week 1         | Steps 1, 2 (Google, Apple, Bing, Yelp), Step 8 (5 first review requests) |
| Week 2         | Step 3 (Facebook, Instagram), Step 4 (Foursquare) |
| Week 3-4       | Step 5 (industry platforms), Step 6 (general directories) |
| Month 2        | Step 8 continued (5 more reviews), Step 7 (AI test) |
| Month 3        | Full audit — search your name on Google + ChatGPT + Yelp. Everything still accurate? |
| Quarterly      | Refresh photos, post 1 Google Business update, check new reviews |
| Annually       | Verify all links still work, update hours (holidays, vacations) |

### Step 10 — Free tools to track progress

- **Google Search Console** — see how Google views your site:
  https://search.google.com/search-console
- **Google Business Insights** — inside your Google Business Profile,
  shows what searches lead to you.
- **BrightLocal Free Tools** — verify NAP consistency across directories:
  https://www.brightlocal.com/free-local-tools/
- **PageSpeed Insights** — confirm site stays fast:
  https://pagespeed.web.dev/

### Common mistakes to avoid

- ❌ Different info on Yelp vs Google.
- ❌ Ignoring reviews (negative AND positive).
- ❌ Blurry or flash-lit photos.
- ❌ Not updating hours for holidays.
- ❌ Buying reviews (Google detects and demotes).
- ❌ Creating multiple Google profiles for the same business (Google
  penalizes duplicates).
- ❌ Phone number that differs from your business registration.

---

# SECTION C — Non-local web, FRENCH

Insert verbatim into the deliverable when `LANG=fr` AND
`IS_LOCAL_BUSINESS=false` AND `PROJECT_TYPE=web`.

## 8. Améliorer la visibilité de votre site — ce qui dépend de vous

### Pourquoi ce chapitre

Le site est en ligne et techniquement optimisé pour le référencement.
La suite dépend de **vous** : revendiquer votre marque sur les bons
outils, faire indexer le site, obtenir des liens entrants, et apparaître
dans les nouveaux moteurs de recherche IA (ChatGPT, Perplexity, Gemini).

### Étape 1 — Indexation chez Google et Bing

**Google Search Console** — l'outil officiel Google pour suivre votre
site et lui dire d'indexer vos pages.
- Inscription : https://search.google.com/search-console
- Actions :
  - ☐ Vérifier la propriété (DNS ou fichier HTML — votre développeur peut
    aider).
  - ☐ Soumettre le sitemap.xml (URL : votresite.com/sitemap.xml)
  - ☐ Vérifier qu'il n'y a pas d'erreur d'indexation
  - ☐ Surveiller les requêtes qui mènent à vous (1 fois par mois)

**Bing Webmaster Tools** — équivalent Bing, alimente aussi ChatGPT.
- Inscription : https://www.bing.com/webmasters
- ☐ Compte créé
- ☐ Sitemap soumis
- ☐ Importer depuis Google Search Console (option "Importer")

### Étape 2 — Présence sur les réseaux pertinents

À adapter selon votre activité :

| Type de projet      | Plateforme                            | Lien |
|---------------------|----------------------------------------|------|
| B2B / pro           | LinkedIn Company Page                  | https://www.linkedin.com/company/setup/new/ |
| Startup / produit   | Product Hunt (lancement)               | https://www.producthunt.com/posts/new |
| Startup             | Crunchbase                             | https://www.crunchbase.com/add-new |
| SaaS                | G2 / Capterra                          | https://www.g2.com/, https://www.capterra.com/ |
| Open source         | GitHub topics + README badges          | (votre repo GitHub) |
| Portfolio créatif   | Behance / Dribbble                     | https://www.behance.net/ |
| Blog / newsletter   | Substack / Medium republish            | https://substack.com/ |
| Boutique en ligne   | Trustpilot / Avis Vérifiés             | https://business.trustpilot.com/ |

### Étape 3 — Liens entrants (la base du SEO)

Google classe les sites en partie par les liens reçus depuis d'autres
sites. Vous ne pouvez pas en acheter (Google pénalise) — il faut les
mériter.

Idées concrètes :
- ☐ Demander aux partenaires (fournisseurs, clients pro) de vous citer
  avec un lien sur leur site.
- ☐ Publier un article invité sur un blog du secteur.
- ☐ Créer du contenu utile (guide, comparatif, étude) que d'autres
  voudront citer.
- ☐ S'inscrire dans 2-3 annuaires sectoriels reconnus (pas les fermes
  de liens — privilégiez la qualité).
- ☐ Si vous êtes cité dans un article presse : demander que le lien
  soit un vrai lien cliquable (pas juste votre nom en gras).

### Étape 4 — Visibilité sur les IA (GEO)

**Test en direct** :
1. Allez sur https://chat.openai.com/, demandez : "Quels sont les
   meilleurs sites pour [ce que vous faites] ?"
2. Pareil sur https://www.perplexity.ai/, https://claude.ai/,
   https://gemini.google.com/
3. Notez ce qui apparaît.

**Côté technique** (déjà fait sur votre site) : Schema.org JSON-LD,
balises Open Graph, sitemap, robots.txt qui autorise les crawlers IA
(GPTBot, ClaudeBot, PerplexityBot).

**Côté contenu** (à faire par vous ou un rédacteur) :
- Ajouter une page FAQ (les IA adorent extraire des Q→R).
- Écrire en début de paragraphe la réponse, puis détailler (les IA
  citent les premières lignes).
- Mettre à jour le contenu (les IA préfèrent les pages récentes).

**Wikidata** (si pertinent) : créer une fiche pour votre marque, votre
produit, ou votre fondateur. Ça aide les IA à vous reconnaître.
- https://www.wikidata.org/wiki/Special:CreateAccount

### Étape 5 — Mesure et ajustement

Outils gratuits :
- Google Search Console — trafic et requêtes
- Google Analytics 4 — comportement des visiteurs (https://analytics.google.com/)
- Plausible / Simple Analytics — alternatives respectueuses de la vie
  privée et conformes RGPD
- PageSpeed Insights — vitesse du site (https://pagespeed.web.dev/)

Calendrier :
| Quand        | Action |
|--------------|--------|
| Semaine 1    | Search Console + Bing Webmaster + sitemap |
| Mois 1       | Réseaux pertinents + 3 premiers liens entrants |
| Mois 2-3     | Création de contenu (1 article ou guide / mois) |
| Trimestriel  | Audit SEO complet (rerun `/seo` avec votre dev) |

### Erreurs à éviter

- ❌ Acheter des liens — Google détecte et déclasse.
- ❌ Lancer un blog et l'abandonner après 2 articles.
- ❌ Ignorer Search Console pendant 6 mois.
- ❌ Bloquer les crawlers IA dans robots.txt (vérifier que GPTBot,
  ClaudeBot, etc., sont autorisés si vous voulez apparaître).

---

# SECTION D — Non-local web, ENGLISH

Insert verbatim when `LANG=en` AND `IS_LOCAL_BUSINESS=false` AND
`PROJECT_TYPE=web`.

## 8. Improving Your Site's Visibility — What's On You

### Why this chapter exists

The site is live and technically SEO-optimized. The rest is on **you**:
claim your brand on the right tools, get the site indexed, earn
backlinks, and show up in new AI search engines (ChatGPT, Perplexity,
Gemini).

### Step 1 — Indexation on Google and Bing

**Google Search Console** — Google's official tool to track your site
and request page indexing.
- Sign up: https://search.google.com/search-console
- Tasks:
  - ☐ Verify ownership (DNS or HTML file — your developer can help)
  - ☐ Submit sitemap.xml (URL: yoursite.com/sitemap.xml)
  - ☐ Confirm no indexing errors
  - ☐ Monitor queries leading to you (monthly)

**Bing Webmaster Tools** — Bing equivalent, also feeds ChatGPT.
- Sign up: https://www.bing.com/webmasters
- ☐ Account created
- ☐ Sitemap submitted
- ☐ Import from Google Search Console (use the "Import" option)

### Step 2 — Presence on relevant networks

Adapt to your activity:

| Project type        | Platform                              | URL |
|---------------------|---------------------------------------|-----|
| B2B / pro           | LinkedIn Company Page                 | https://www.linkedin.com/company/setup/new/ |
| Startup / product   | Product Hunt (launches)               | https://www.producthunt.com/posts/new |
| Startup             | Crunchbase                            | https://www.crunchbase.com/add-new |
| SaaS                | G2 / Capterra                         | https://www.g2.com/, https://www.capterra.com/ |
| Open source         | GitHub topics + README badges         | (your GitHub repo) |
| Creative portfolio  | Behance / Dribbble                    | https://www.behance.net/ |
| Blog / newsletter   | Substack / Medium republish           | https://substack.com/ |
| E-commerce          | Trustpilot                            | https://business.trustpilot.com/ |

### Step 3 — Backlinks (the SEO foundation)

Google ranks sites partly by who links to them. You can't buy these
(Google penalizes) — you have to earn them.

Concrete ideas:
- ☐ Ask partners (suppliers, clients) to link to you on their site.
- ☐ Publish a guest article on an industry blog.
- ☐ Create useful content (guide, comparison, case study) others will
  want to cite.
- ☐ Register in 2-3 reputable industry directories (avoid link farms —
  quality over quantity).
- ☐ If a press article cites you: ask that the citation be a real
  clickable link (not just bolded text).

### Step 4 — AI visibility (GEO)

**Live test**:
1. Go to https://chat.openai.com/, ask: "What are the best sites for
   [what you do]?"
2. Same on https://www.perplexity.ai/, https://claude.ai/,
   https://gemini.google.com/
3. Note what appears.

**Technical side** (already done): Schema.org JSON-LD, Open Graph,
sitemap, robots.txt allowing AI crawlers (GPTBot, ClaudeBot,
PerplexityBot).

**Content side** (your job or a writer's):
- Add a FAQ page (AI loves extracting Q→A).
- Lead each paragraph with the answer, then detail (AI quotes opening
  lines).
- Refresh content (AI prefers recent pages).

**Wikidata** (if relevant): create a Wikidata entry for your brand,
product, or founder. Helps AI engines recognize you.
- https://www.wikidata.org/wiki/Special:CreateAccount

### Step 5 — Measure and iterate

Free tools:
- Google Search Console — traffic and queries
- Google Analytics 4 — visitor behavior (https://analytics.google.com/)
- Plausible / Simple Analytics — privacy-friendly, GDPR-compliant
- PageSpeed Insights — site speed (https://pagespeed.web.dev/)

Timeline:
| When         | Action |
|--------------|--------|
| Week 1       | Search Console + Bing Webmaster + sitemap |
| Month 1      | Relevant networks + first 3 backlinks |
| Month 2-3    | Content creation (1 article or guide / month) |
| Quarterly    | Full SEO audit (rerun `/seo` with your dev) |

### Mistakes to avoid

- ❌ Buying links — Google detects and demotes.
- ❌ Launching a blog and abandoning it after 2 posts.
- ❌ Ignoring Search Console for 6 months.
- ❌ Blocking AI crawlers in robots.txt (verify GPTBot, ClaudeBot, etc.
  are allowed if you want AI visibility).

---

# COMMON — AI visibility deep-dive (used in all sections)

The agent may need to expand the AI section depending on the project's
sophistication. Use these snippets as building blocks.

## AI crawlers allowlist (technical reference)

If the client asks "are AI engines allowed to read my site?", check
`robots.txt`. The following crawlers should NOT be disallowed if AI
visibility is wanted:

```
User-agent: GPTBot
User-agent: ChatGPT-User
User-agent: OAI-SearchBot
User-agent: ClaudeBot
User-agent: Claude-Web
User-agent: anthropic-ai
User-agent: PerplexityBot
User-agent: Perplexity-User
User-agent: Google-Extended
User-agent: Bingbot
User-agent: CCBot
User-agent: Bytespider
User-agent: Diffbot
User-agent: DuckAssistBot
User-agent: Applebot-Extended
```

If the client wants to OPT OUT of AI training, those should be
disallowed. Be explicit: visibility ≠ training opt-in. Some bots only
read for live answers (GPTBot in search mode), others for training.
Defer to legal preference.

## llms.txt

`llms.txt` is an emerging standard (similar role to robots.txt but for
AI). If the site has one, mention it to the client. If not, defer —
this is technical, not their job.

## Schema.org types worth checking

The agent should not list these to the client unless asked. Internal
reference for the developer:

- `Organization` (always)
- `LocalBusiness` (and subtypes: Restaurant, Hotel, MedicalBusiness, etc.)
- `Person` (founder, key staff)
- `Product` (e-commerce)
- `Service` (services)
- `FAQPage` (helps AI extraction)
- `Article` (blog content)
- `BreadcrumbList` (navigation context)
- `AggregateRating` (review counts)

---

# MAINTENANCE NOTES

- Re-verify all signup URLs annually.
- Add new platforms as they emerge (TikTok Maps, Threads, Bluesky,
  Mastodon for community, etc.).
- Track which platforms the agent's `WebFetch` checks fail on — those
  may have changed signup URLs.
- AI crawler list grows monthly. Sync with `~/.claude/agents/resources/
  ai-crawlers-2026.md` if it exists.
