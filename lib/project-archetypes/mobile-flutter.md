---
name: mobile-flutter
category: mobile
public: true
database: optional
hosting_hints:
  - app-store
  - play-store
  - huawei-appgallery
  - web-hosting
  - desktop-distribution
audit_stack:
  - analyze
  - code-clean
  - design-review
  - perf
  - cso
  - a11y
  - doc
plugins:
  context7: optional
  ui-ux-pro-max: yes
  gstack: no
---

# Mobile Flutter

Application Flutter (Dart) cible iOS + Android + Web + Desktop. Widgets tree, state management variable (Provider / Riverpod / Bloc / GetX).

## Detection signals

### Strong signals (×3)
- FILE: `pubspec.yaml`
- FILE: `pubspec.lock`
- DIR: `lib/` AVEC fichiers `.dart`
- FILE: `lib/main.dart`

### Medium signals (×2)
- DIR: `android/`
- DIR: `ios/`
- FILE: `analysis_options.yaml`
- DIR: `test/` AVEC `.dart`
- DEP dans pubspec.yaml: "flutter_bloc", "provider", "riverpod", "get"

### Weak signals (×1)
- DIR: `web/`, `macos/`, `linux/`, `windows/` (multi-plateforme)
- FILE: `l10n.yaml` (i18n)
- DIR: `assets/images/`, `assets/fonts/`
- FILE: `.flutter-plugins`, `.flutter-plugins-dependencies`

### Counter-signals (exclusion)
- DEP pubspec contient "dart_sdk" uniquement sans "flutter" → projet Dart pur (CLI / server), pas Flutter

## Implications
- **Distribution** : App Store / Play Store / AppGallery (Huawei) / Web (Flutter Web) / Desktop (macOS/Win/Linux via Flutter desktop)
- **Base de données** : locale (sqflite / Hive / Isar / Drift) + backend (Firebase / Supabase / API custom)
- **SEO/GEO** : PARTIEL si Flutter Web — Flutter Web rend en canvas/HTML, SEO limité même en HTML renderer
- **Surface sécurité** : GRANDE — shared_preferences non chiffré, secrets dans bundle, deep links
- **UI/UX** : CRITIQUE — design system Material/Cupertino + custom

## Typical pain points
- Secrets / API keys dans `pubspec.yaml` ou `lib/config.dart` committés
- `shared_preferences` pour tokens → pas chiffré (doit être `flutter_secure_storage`)
- State management non cohérent (mélange setState + Provider + Bloc dans même app)
- Rebuild excessif (pas de `const` widgets, pas de `Selector`, pas de keys)
- Performances listes : pas de `ListView.builder` (rend tout d'un coup)
- Images non optimisées (pas de `cached_network_image`, pas de compression)
- Pas de splash screen natif (flash blanc au démarrage)
- Permissions iOS/Android demandées sans justification → reject App Store
- Pas de crash reporting (Sentry / Firebase Crashlytics absents)
- Deep links non configurés / uni_links / go_router mal configurés
- Pas de tests unitaires / widget tests
- Pas de tests E2E (integration_test / Patrol / Maestro)
- Flutter SDK obsolète (cycle release rapide)
- `flutter pub outdated` ignoré → deps avec failles
- Accessibilité : `Semantics` widget pas utilisé, focus order incorrect
- Dark mode : `ThemeMode.system` pas supporté ou mal
- i18n : strings hardcodées au lieu de `.arb` files
- Platform channels pas testés (plugins natifs)
- Code generation (build_runner) pas dans CI → fichiers générés commités
- App bundle size énorme (pas de `--split-per-abi` Android, pas de tree shaking)

## Interview questions (adaptive)
En plus du set minimum business :
- State management : Provider / Riverpod / Bloc / GetX / Cubit / vanilla ?
- Flutter SDK / Dart version ?
- Targets : iOS / Android / Web / macOS / Windows / Linux ?
- Navigation : Navigator 1.0 / go_router / auto_route / beamer ?
- Backend : Firebase / Supabase / API custom / GraphQL ?
- Auth : provider + storage (flutter_secure_storage obligatoire pour tokens) ?
- Database locale : sqflite / Hive / Isar / Drift / SharedPreferences ?
- Push notifications : FCM / OneSignal / Notifee / aucun ?
- Crash reporting : Firebase Crashlytics / Sentry / aucun ?
- Analytics : Firebase / Amplitude / PostHog / aucun ?
- Tests : unit / widget / integration / Patrol ?
- CI/CD : Codemagic / Bitrise / GitHub Actions / Fastlane / aucun ?
- Code generation : build_runner / freezed / json_serializable / riverpod_generator ?
- i18n : `flutter_localizations` + .arb ?
- Design system : Material 3 / Cupertino / custom tokens ?
- Dark mode supporté ?
- Accessibilité : Semantics widgets + testé VoiceOver / TalkBack ?
- App bundle size cible ?
- App Store Review : première soumission / rejet déjà eu / actif ?

## Plugin recommendations
- **context7** : OPTIONAL — ON pour Flutter 3.x récent (Impeller, Material 3, Riverpod 2+)
- **ui-ux-pro-max** : ON
- **gstack** : OFF

## Example project layout
```
pubspec.yaml
pubspec.lock
analysis_options.yaml
lib/
  main.dart
  app.dart
  core/
    theme.dart
    constants.dart
  features/
    auth/
      data/
      domain/
      presentation/
    home/
      data/
      domain/
      presentation/
  shared/
    widgets/
    services/
test/
  widget_test.dart
  features/
    auth_test.dart
integration_test/
  app_test.dart
assets/
  images/
  fonts/
android/
ios/
web/
l10n.yaml
```
