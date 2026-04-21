---
name: game-engine-native
category: game
public: true
database: optional
hosting_hints:
  - steam
  - itch-io
  - gog
  - epic-store
  - app-stores
  - console-stores
audit_stack:
  - analyze
  - code-clean
  - perf
  - design-review
  - a11y
  - doc
plugins:
  context7: no
  ui-ux-pro-max: optional
  gstack: no
---

# Game Engine Native (Godot / Unity)

Projet de jeu utilisant un moteur natif : Godot (GDScript / C#) ou Unity (C#). Distribution standalone desktop / mobile / console, parfois web export.

## Detection signals

### Strong signals (×3)
- FILE: `project.godot` (Godot)
- DIR: `ProjectSettings/` contenant `*.asset` (Unity)
- FILE: `Assets/Settings/*.asset` OR `Packages/manifest.json` (Unity)
- EXT: 5+ fichiers `.gd` (Godot GDScript)
- EXT: 5+ fichiers `.unity` (Unity scene files)

### Medium signals (×2)
- DIR: `scenes/` AVEC `.tscn` (Godot)
- DIR: `Assets/Scripts/` AVEC `.cs` (Unity)
- DIR: `addons/` (Godot custom plugins)
- DIR: `Library/` (Unity, gitignored normalement)
- FILE: `.godot/` directory (Godot cache)
- DEP: `Packages/manifest.json` contient "com.unity.*"

### Weak signals (×1)
- DIR: `.gitattributes` avec LFS rules pour assets binaires
- EXT: `.tres` (Godot resources), `.prefab` (Unity)
- DIR: `Builds/` OR `exports/` (builds sortie)
- FILE: `.gdignore` OR `.gitignore` avec patterns Unity/Godot

### Composition overlays
- **Godot 4 vs 3** : détection sur `config_version=5` (Godot 4) vs `config_version=4` (Godot 3)
- **Unity URP / HDRP / Built-in** : `Assets/Settings/URP-*.asset` / `HDRenderPipelineAsset.asset`
- **C# in Godot** : FILE `*.csproj` AVEC Godot references

## Implications
- **Distribution** : Steam, itch.io, GOG, Epic Store, App Store, Play Store, consoles (avec portage)
- **Base de données** : OPTIONNELLE — save files locaux, backends externes possibles (Unity Gaming Services, PlayFab, Firebase)
- **SEO/GEO** : N/A (sauf page produit sur Steam / site du jeu)
- **Surface sécurité** : MOYENNE — anti-cheat si multiplayer, injection via mods, DLC entitlements
- **UI/UX** : CRITIQUE — game feel + UI in-game + onboarding + accessibilité

## Typical pain points
- Assets volumineux (textures, audio, modèles 3D) NON en LFS → repo bloat / clone lent
- Meta files (.meta Unity) non commités → references cassées en équipe
- Scene conflicts Unity (YAML non mergeable) sans SmartMerge configuré
- Pas de CI build (builds manuels depuis l'éditeur, erreurs env-specific)
- Pas de tests (Unity Test Framework / GUT Godot rarement utilisés)
- Hardcoded paths (résolution, language, keymaps)
- Input non rebindable (clavier/manette)
- Accessibilité catastrophique : pas de color-blind mode, pas de subtitles, pas d'options motion
- Pas de pause propre (main menu ok, mais in-game pause buggé)
- Performances non profilées (frame drops sans diagnostic)
- Memory leaks : particules non freed, signals non disconnect, scenes non queue_free
- Localisation absente ou hardcodée (pas de `.po` / `.csv` / Unity Localization Package)
- Save files en clair dans `%APPDATA%` / `~/Library/Application Support` — triche triviale
- Multiplayer : auth client-side, state non validé server-side
- Modding non supporté (absence d'API plugins)
- Pas d'analytics respectueux RGPD (opt-in, anonymisé)
- Build size non optimisé (toutes textures en 4K, pas de compression format GPU)
- Pas d'Over-the-air patches (cycles Steam update long)
- Audio non mixé (master bus saturé, pas de ducking, pas d'accessibilité audio)
- Shaders custom non cross-platform (Metal vs Vulkan vs DX12 vs OpenGL ES)

## Interview questions (adaptive)
En plus du set minimum business :
- Moteur : Godot (3.x / 4.x) / Unity (version LTS / Alpha) / autre ?
- Langage : GDScript / C# (Godot Mono) / C# Unity ?
- Pipeline rendu Unity : Built-in / URP / HDRP ?
- Version control : Git LFS activé ? Unity SmartMerge configuré ? Plastic SCM ?
- Scène principale + architecture : monolithique / modulaire (additive scenes) ?
- Type de jeu : 2D / 3D / first-person / third-person / puzzle / MMO / ... ?
- Solo / coop local / multiplayer online / les deux ?
- Multiplayer : Mirror / Netcode for GameObjects / Fishnet / Godot High-Level Multiplayer / Photon / autre ?
- Analytics : Unity Analytics / custom / aucun ?
- Save system : binaire / JSON / steam cloud / server-side ?
- Localisation : Unity Localization / Godot tr() / externe ?
- Input System : Unity Input System / InputManager legacy / Godot InputMap ?
- Cibles plateformes : PC (Windows/macOS/Linux) / mobile / consoles (PS/Xbox/Switch) ?
- Distribution : Steam / itch.io / GOG / Epic / App Store / consoles ?
- Anti-cheat si multiplayer ?
- Modding prévu ?
- Accessibilité : color-blind mode / subtitles / motion options / remappable controls / haptic alternatives ?
- Audio mixing + ducking fait ?
- CI builds : GitHub Actions / CircleCI / Unity Cloud Build / Jenkins ?
- Tests : Unity Test Framework / GUT (Godot) / Gherkin ?
- Profiling : Unity Profiler / Godot Debugger / RenderDoc / autre ?
- Analytics respecte RGPD ?

## Plugin recommendations
- **context7** : OFF — docs engines (Godot, Unity) stables, context7 peu utile
- **ui-ux-pro-max** : OPTIONAL — utile pour UI menus HUD, peu pour gameplay
- **gstack** : OFF

## Example project layout (Godot 4)
```
project.godot
.gitignore                 (exclude .godot/, export/, *.tmp)
.gitattributes             (LFS for .png .wav .ogg .glb .tres binaires)
scenes/
  main.tscn
  levels/
    level_01.tscn
  ui/
    main_menu.tscn
scripts/
  player.gd
  enemy.gd
  systems/
    save_system.gd
assets/
  sprites/
  audio/
  fonts/
addons/
  dialogue_manager/
exports/                   (gitignored)
.godot/                    (cache, gitignored)
```

## Example project layout (Unity)
```
Assets/
  Scripts/
    Player/
    Enemies/
    Systems/
      SaveSystem.cs
  Scenes/
    MainMenu.unity
    Level_01.unity
  Prefabs/
  Materials/
  Settings/
    URP-Renderer.asset
    InputActions.inputactions
  Localization/
ProjectSettings/
Packages/
  manifest.json
  packages-lock.json
.gitattributes             (LFS for binary assets)
.gitignore                 (exclude Library/, Temp/, Builds/)
```
