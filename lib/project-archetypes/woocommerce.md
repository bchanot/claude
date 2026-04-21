---
name: woocommerce
category: cms
public: true
database: required
hosting_hints:
  - vps
  - managed-wp
  - woocommerce-com
  - docker
audit_stack:
  - analyze
  - code-clean
  - seo
  - design-review
  - perf
  - cso
  - a11y
  - doc
plugins:
  context7: no
  ui-ux-pro-max: yes
  gstack: optional
---

# WooCommerce (WordPress e-commerce)

Extension WordPress pour e-commerce. Archétype **composé** : hérite de wordpress + ajoute e-commerce (PII, paiements, stocks).

## Detection signals

Présuppose que `wordpress.md` a déjà matché (fortement ou moyennement). Signaux additionnels pour ajouter l'overlay WooCommerce :

### Strong signals (×3)
- DIR: `wp-content/plugins/woocommerce/`
- FILE: `wp-content/plugins/woocommerce/woocommerce.php`
- DEP: `composer.json` contient "woocommerce/woocommerce" (Composer-managed WP)

### Medium signals (×2)
- STRING_IN_FILE: thème actif `functions.php` contient "add_theme_support( 'woocommerce' )"
- DIR: `wp-content/themes/*/woocommerce/` (template overrides)
- DIR: `wp-content/plugins/woocommerce-*/` (extensions WC : shipping, payments, subscriptions)

### Weak signals (×1)
- STRING_IN_FILE: database dumps / SQL contient tables "wp_wc_*" OR "wp_woocommerce_*"
- DEP: `@woocommerce/*` dans package.json (blocks custom)

## Implications (en plus de wordpress.md)
- **Surface sécurité** : **TRÈS GRANDE** — paiements, PII clients, tokens passerelles
- **Conformité** : PCI-DSS indirecte (via gateway), RGPD (données clients), consentement cookies obligatoire
- **SEO/GEO** : CRITIQUE — schema Product + Offer + Review obligatoire
- **Perf** : critique pour conversion (LCP < 2.5s idéal checkout)

## Typical pain points (en plus de WordPress)
- Extensions WC obsolètes (WooCommerce Payments, Subscriptions, Stripe Gateway) — failles récurrentes
- Template overrides thème non mis à jour avec les changements core WC → bugs silencieux
- Pas de schema.org Product / Offer / AggregateRating
- Checkout lent (plugins overload, AJAX chain)
- Variations produits : performances DB catastrophiques au-delà de 500 produits sans index
- Stocks non synchronisés avec ERP / marketplaces (Amazon, Etsy)
- Backup produits / commandes absent
- Logs d'erreur checkout non monitorés → ventes perdues silencieuses
- Emails transactionnels non délivrés (SMTP absent, spam folder)
- HPOS (High-Performance Order Storage) non migré (WC 8+)
- Taxes mal configurées (TVA intracommunautaire, prix HT/TTC)
- PII stockée en clair (numéros téléphones, adresses)

## Interview questions (adaptive)
En plus des questions wordpress.md :
- Volume produits (catalogue simple ou milliers) ?
- Variations produits (tailles, couleurs, bundles) ?
- Volume commandes mensuel ?
- Gateway de paiement : Stripe / PayPal / WC Payments / autre ?
- Abonnements (WC Subscriptions) ?
- Multi-devise / multi-langue ?
- Gestion stocks (manuelle / ERP synchronisé) ?
- Marketplaces connectés (Amazon, eBay, Etsy) ?
- HPOS activé (WC 8.2+) ?
- RGPD / consentement cookies en place ?
- Emails transactionnels (SMTP configuré / via plugin / via Mailgun/Postmark) ?
- Monitoring erreurs checkout ?

## Plugin recommendations
- **ui-ux-pro-max** : ON — parcours d'achat = UX intensive
- **gstack** : RECOMMANDÉ — Lighthouse + audit checkout flow
- **context7** : OFF

## Example project layout (en plus de wordpress.md)
```
wp-content/
  plugins/
    woocommerce/
    woocommerce-stripe-gateway/
    woocommerce-subscriptions/
  themes/
    mon-theme-wc/
      woocommerce/          ← template overrides
        single-product.php
        cart/cart.php
      functions.php          ← add_theme_support('woocommerce')
```
