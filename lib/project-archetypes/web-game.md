---
name: web-game
category: game
public: true
database: optional
hosting_hints:
  - itch-io
  - netlify
  - cloudflare-pages
  - vercel
  - github-pages
  - newgrounds
audit_stack:
  - analyze
  - code-clean
  - perf
  - design-review
  - a11y
  - cso
  - doc
plugins:
  context7: optional
  ui-ux-pro-max: optional
  gstack: optional
---

# Web Game (browser-based)

Jeu web navigateur — Phaser / Pixi.js / Three.js / Babylon.js / p5.js / Matter.js / Canvas 2D / WebGL brut. Distribution : itch.io / Newgrounds / site dédié / portail HTML5.

## Detection signals

### Strong signals (×3)
- DEP: `package.json` contient l'un de : "phaser", "pixi.js", "three", "babylonjs" OR "@babylonjs/core", "matter-js", "p5"
- STRING_IN_FILE: tout .js/.ts contient "new Phaser.Game(" OR "new PIXI.Application(" OR "new THREE.Scene(" OR "BABYLON.Engine("

### Medium signals (×2)
- DIR: `src/scenes/` OR `src/entities/` OR `src/sprites/`
- FILE: `game.config.js` OR `src/config.js` avec game settings
- DEP: "howler" OR "tone" OR "sound.js" (audio)
- DEP: "gsap" OR "@tweenjs/tween.js" (animations)

### Weak signals (×1)
- DIR: `assets/sprites/` OR `assets/audio/` OR `assets/tilesets/`
- EXT: `.atlas` OR `.tmx` (Tiled maps)
- DEP: "webpack" OR "vite" (bundler)
- FILE: `index.html` avec `<canvas>` ou `<div id="game">`

### Counter-signals (exclusion)
- DEP: "react-three-fiber" sans Three.js scène principale → peut être composant 3D dans app React (pas un jeu)

## Implications
- **Hébergement** : itch.io (dominant indie), Newgrounds, Cloudflare Pages, Netlify, GitHub Pages, site custom
- **Base de données** : OPTIONNELLE — souvent localStorage pour saves, parfois backend pour leaderboard/multiplayer
- **SEO/GEO** : IMPORTANT si monétisation via portail web (mais jeu lui-même = canvas opaque)
- **Surface sécurité** : MOYENNE-GRANDE si multiplayer ou backend (anti-cheat, auth)
- **UI/UX** : CRITIQUE — game feel, juice, feedback

## Typical pain points
- FPS instable (pas de rAF, setInterval utilisé, physics tickée dans render)
- Assets chargés tous au démarrage (loading screen 30s) au lieu de streaming
- Sprites non atlas (chaque image = requête réseau)
- Audio non compressé (WAV uncompressed au lieu de OGG/WebM)
- Pas de fallback WebGL → Canvas2D (GPU insuffisant = écran noir)
- Memory leaks (scenes non destroy-ées, event listeners non cleanup)
- Input hardcoded (pas de rebind, pas de support manette via Gamepad API)
- Pas de pause native (perte focus tab = jeu continue en bg)
- Persistance : localStorage (limitation 5MB, synchrone, bloquant)
- Pas de save cloud ni cross-device
- Multiplayer : auth client-side uniquement (triche triviale)
- Accessibilité : pas d'options (no-motion, color-blind, subtitle, remappable controls)
- Perf mobile : jeu pensé desktop, pas touch-optimized, pas adaptatif
- Monétisation : ads ou IAP sans consentement RGPD
- Analytics intrusifs (user tracking sans consentement)

## Interview questions (adaptive)
En plus du set minimum business :
- Moteur / framework : Phaser / Pixi / Three / Babylon / p5 / custom canvas / autre ?
- Type de jeu : 2D / 3D / isométrique / top-down / platformer / puzzle / runner / autre ?
- Solo / multijoueur / les deux ?
- Persistance : localStorage / IndexedDB / backend (lequel) / cloud saves ?
- Cible : desktop seulement / mobile / tablette / manette ?
- FPS cible : 60 / 120 / variable ?
- Monétisation : gratuit / premium / free-to-play + ads / IAP ?
- Plateforme de distribution : itch.io / Newgrounds / site custom / Steam (via Electron ?) / autre ?
- Multi-langue prévu ?
- Audio : effets + musique ? compression ?
- Rebind controls / manette prévu ?
- Accessibilité : options (reduced motion / subtitles / color-blind) ?
- Ads réseau si free : lequel ?
- Leaderboard / social ?

## Plugin recommendations
- **context7** : OPTIONAL — ON si Three/Babylon récents
- **ui-ux-pro-max** : OPTIONAL — utile pour UI menus (pas pour gameplay)
- **gstack** : OPTIONAL — tester sur navigateur

## Example project layout
```
index.html
package.json
vite.config.ts
src/
  main.ts
  game.ts
  config.ts
  scenes/
    BootScene.ts
    MenuScene.ts
    GameScene.ts
    UIScene.ts
  entities/
    Player.ts
    Enemy.ts
  systems/
    InputManager.ts
    AudioManager.ts
    SaveSystem.ts
  data/
    levels.json
assets/
  sprites/
    player.atlas
    enemies.png
  audio/
    music.ogg
    sfx/
  tilesets/
    world.tmx
public/
  index.html
```
