---
name: mobile-expo
category: mobile
public: true
database: optional
hosting_hints:
  - app-store
  - play-store
  - expo-go
  - eas-build
audit_stack:
  - analyze
  - code-clean
  - design-review
  - perf
  - cso
  - a11y
  - doc
plugins:
  context7: yes
  ui-ux-pro-max: yes
  gstack: no
---

# Mobile Expo / React Native

Application mobile React Native gérée par Expo (managed workflow) ou bare React Native. Distribution iOS + Android via App Store / Play Store, ou Expo Go en dev.

## Detection signals

### Strong signals (×3)
- FILE: `app.json` OR `app.config.js` OR `app.config.ts` contenant "expo"
- DEP: `package.json` contient "expo"
- FILE: `metro.config.js` OR `metro.config.ts`
- DEP: "react-native"

### Medium signals (×2)
- DEP: "expo-router", "@expo/vector-icons", "expo-font"
- DIR: `app/` (Expo Router file-system routing) avec `.tsx`
- DIR: `assets/` avec `icon.png`, `splash.png`
- FILE: `eas.json` (EAS Build)
- FILE: `babel.config.js` avec preset "babel-preset-expo"

### Weak signals (×1)
- DIR: `android/`, `ios/` (bare workflow uniquement)
- DEP: "react-navigation" OR "@react-navigation/native"
- DEP: "@supabase/supabase-js" OR "firebase" OR "@tanstack/react-query"

### Counter-signals
- DEP: "next" ET .tsx au root → c'est Next.js (web), pas Expo
- FILE: `astro.config.*` → Astro

## Implications
- **Distribution** : App Store (iOS), Play Store (Android), Expo Go (dev), internal distribution (TestFlight/Play Console Internal)
- **Base de données** : locale (AsyncStorage / SQLite / MMKV / WatermelonDB) + backend (Supabase / Firebase / API custom)
- **SEO/GEO** : N/A (app native)
- **Surface sécurité** : GRANDE — AsyncStorage non chiffré par défaut, secrets côté app, deep links exploitables
- **UI/UX** : CRITIQUE — mobile = exigences spécifiques (gestures, haptics, safe area)

## Typical pain points
- Secrets / API keys dans `app.json` → exposés dans le bundle
- AsyncStorage utilisé pour tokens → JWT en clair sur l'appareil
- Pas d'expo-secure-store ou react-native-keychain pour secrets
- Permissions iOS/Android demandées mal justifiées (rejet review)
- Performances : listes longues sans FlatList/FlashList (re-render entier)
- Images non optimisées / pas de `expo-image` (cache + formats)
- Pas de splash screen configuré → écran blanc au démarrage
- Icône app basse résolution
- Deep links non configurés / configurés sans validation
- Pas de crash reporting (Sentry / Bugsnag absents)
- Expo SDK obsolète (upgrade annuel obligatoire)
- Bare workflow sans CI/CD (builds manuels en local)
- Tests E2E absents (Detox / Maestro non configurés)
- i18n absent ou hardcodé
- Accessibilité : `accessibilityLabel` absent, focus order cassé, contrast insuffisant
- Dark mode pas supporté (useColorScheme non utilisé)
- Safe area non respectée (contenu sous notch / home indicator)
- Gestures conflits (swipe drawer vs swipe back iOS)
- Over-the-air updates (expo-updates) non utilisées
- app.json "version" / "buildNumber" non incrémentés

## Interview questions (adaptive)
En plus du set minimum business :
- Workflow : Expo managed / Expo bare / pur React Native ?
- SDK Expo version ?
- Navigation : Expo Router / React Navigation / autre ?
- State : Redux / Zustand / Jotai / Context / React Query seul ?
- Backend : Supabase / Firebase / API custom / BaaS autre ?
- Auth : provider + storage (SecureStore / Keychain / AsyncStorage) ?
- Database locale : AsyncStorage / MMKV / SQLite / WatermelonDB / Realm ?
- Push notifications : Expo Push / FCM / OneSignal / aucun ?
- Crash reporting : Sentry / Bugsnag / aucun ?
- Analytics : Amplitude / Mixpanel / PostHog / Firebase / aucun ?
- Tests : unit (Jest) + E2E (Detox / Maestro) ?
- Build + distribution : EAS Build + EAS Submit / Xcode/Gradle manuels / CI custom ?
- Over-the-air updates activées ?
- Cible OS : iOS min version / Android min API level ?
- Dark mode supporté ?
- i18n : librairie + langues ?
- Accessibilité : audit VoiceOver / TalkBack effectué ?
- App Store Review : première soumission faite / rejetée / en cours ?

## Plugin recommendations
- **context7** : ON — Expo SDK évolue vite (breaking chaque SDK)
- **ui-ux-pro-max** : ON — mobile UX spécifique
- **gstack** : OFF (pas de browser QA)

## Example project layout (Expo Router)
```
app.json                  OR  app.config.ts
package.json
metro.config.js
babel.config.js
eas.json
app/
  _layout.tsx             (root layout)
  index.tsx               (home)
  (tabs)/
    _layout.tsx
    home.tsx
    profile.tsx
  auth/
    login.tsx
components/
  Button.tsx
  Card.tsx
hooks/
lib/
  supabase.ts
assets/
  icon.png
  splash.png
  adaptive-icon.png
  fonts/
.env.example
```
