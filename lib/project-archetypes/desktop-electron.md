---
name: desktop-electron
category: desktop
public: false
database: optional
hosting_hints:
  - github-releases
  - autoupdate-servers
  - mac-app-store
  - microsoft-store
  - snap-store
  - aur
audit_stack:
  - analyze
  - code-clean
  - cso
  - design-review
  - perf
  - a11y
  - doc
plugins:
  context7: yes
  ui-ux-pro-max: yes
  gstack: optional
---

# Desktop Electron

Application desktop basée sur Electron (Chromium + Node.js). Distribution binaires pour macOS / Windows / Linux.

## Detection signals

### Strong signals (×3)
- DEP: `package.json` contient "electron"
- STRING_IN_FILE: tout .js/.ts du projet contient "app.whenReady()" OR "new BrowserWindow(" OR "require('electron')" OR "import .* from 'electron'"
- FILE: `electron-builder.json` OR `electron-builder.yml` OR `forge.config.js` OR `forge.config.ts`

### Medium signals (×2)
- DEP: "electron-builder" OR "@electron-forge/cli"
- DIR: `src/main/` (main process) AND `src/renderer/` (renderer)
- FILE: `main.js` OR `main.ts` OR `src/main/index.ts` (main process entry)
- FILE: `preload.js` OR `src/preload/index.ts`

### Weak signals (×1)
- DIR: `build/` avec icons (icon.icns, icon.ico, icon.png)
- DEP: "electron-updater"
- DEP: "electron-store"
- FILE: `.env.production` avec vars Electron

### Composition overlays
- **Tauri** (NOT Electron but similar archetype) : DEP `@tauri-apps/*` ET `src-tauri/` — à traiter avec archétype `desktop-tauri` (à créer plus tard)
- **Frontend framework inside renderer** : React / Vue / Svelte detected → noter

## Implications
- **Distribution** : GitHub Releases, autoupdate servers, Mac App Store, Microsoft Store, Snap Store, AUR
- **Base de données** : OPTIONNELLE — souvent SQLite via better-sqlite3 ou electron-store (JSON)
- **SEO/GEO** : N/A (app native desktop)
- **Surface sécurité** : **CRITIQUE** — accès file system, shell, nodeIntegration si mal config = RCE
- **UI/UX** : CRITIQUE — conventions desktop par OS

## Typical pain points
- `nodeIntegration: true` et `contextIsolation: false` dans BrowserWindow → XSS = exécution code natif arbitraire
- `contextBridge` non utilisé (preload expose Node API brut au renderer)
- `webSecurity: false` (CORS désactivé dans renderer — risque énorme)
- Secrets / API keys dans le bundle (déchiffrable par n'importe quel user — asar non chiffré)
- URL chargée remote dans BrowserWindow → MITM sur un site compromis = RCE
- Pas de code signing (macOS Gatekeeper / Windows SmartScreen avertissements)
- Pas d'autoupdate (`electron-updater`) → users bloqués sur vieilles versions faillibles
- Electron version obsolète (updates mensuelles critiques)
- Shell IPC non validé (renderer peut exécuter commandes shell via ipcMain mal filtré)
- `navigator.userAgent` leak (app detectable, fingerprint)
- Menu context / clipboard : permissions non gérées
- Deep links (`app://`) non validés → phishing
- Accessibilité OS : ARIA ignoré, screen readers non testés
- Taille du bundle énorme (Chromium = 150-200MB)
- Performances : main process bloqué par ops synchrones (fs sync dans main)
- Memory leaks : BrowserWindows non fermés, event listeners non cleanup
- Pas de crash reporting natif (`electron-log`, Sentry Electron)
- Pas de tests E2E (Spectron déprécié, Playwright Electron recommandé)

## Interview questions (adaptive)
En plus du set minimum business :
- Framework build : electron-builder / electron-forge / autre ?
- Frontend dans renderer : React / Vue / Svelte / vanilla / autre ?
- IPC : `ipcMain`+`ipcRenderer` directs / `contextBridge` secure / `@electron/remote` (déprécié) ?
- BrowserWindow config : nodeIntegration / contextIsolation / sandbox / webSecurity ?
- Auth : OAuth desktop / tokens locaux / SSO entreprise ?
- Stockage : electron-store / SQLite (better-sqlite3) / IndexedDB / file system direct / cloud ?
- Code signing : macOS (Developer ID + notarization) / Windows (EV Cert) / aucun ?
- Autoupdate : electron-updater / custom / aucun ?
- Distribution : GitHub Releases / Homebrew Cask / MS Store / Mac App Store / autre ?
- OS cibles : macOS min / Windows min / Linux distros ?
- Architecture : x64 / arm64 / universal2 (macOS) ?
- Electron version + cycle d'upgrade ?
- Crash reporting : Sentry Electron / electron-log / aucun ?
- Analytics : respecte RGPD (opt-in, désactivable) ?
- Tests : unit + Playwright Electron ?
- CI/CD : builds multi-OS (GitHub Actions matrix / CircleCI) ?
- Deep links / protocol handlers registered ?
- App menu + accelerators ?
- Accessibilité OS native testée ?

## Plugin recommendations
- **context7** : ON — Electron évolue vite (mensuel), breaking changes fréquents
- **ui-ux-pro-max** : ON
- **gstack** : OPTIONAL — Playwright peut tester le renderer

## Example project layout
```
package.json
forge.config.ts           OR   electron-builder.json
src/
  main/
    index.ts              (main process)
    window.ts
    menu.ts
    ipc-handlers.ts
  preload/
    index.ts              (contextBridge)
  renderer/
    index.html
    main.tsx              (React/Vue/Svelte app)
    components/
resources/
  icon.icns
  icon.ico
  icon.png
build/
  entitlements.mac.plist
  background.png
.env.example
```
