---
name: init-project
description: Initialise un projet complet from scratch. Structure, stack, fichiers de base, conventions. Orchestration complète avec validation utilisateur.
argument-hint: <description ou idée de projet>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATEUR : INIT PROJECT

Charge et applique strictement :
- .claude/agents/analyzer.md
- .claude/agents/designer.md
- .claude/agents/implementer.md
- .claude/agents/reviewer.md
- .claude/agents/tester.md

---

## PROJET

$ARGUMENTS

---

## WORKFLOW

### 1. ANALYZER
Comprendre :
- Type de projet (web app, API, lib, CLI, etc.)
- Contraintes et préférences de stack
- Repo existant (si applicable)
- Décisions critiques manquantes

### 2. DESIGNER
Définir :
- Architecture
- Stack technique
- Structure des dossiers
- Modules clés
- Conventions du projet

### 3. VALIDATION GATE — STOP OBLIGATOIRE
Présenter :
- Stack choisie
- Architecture
- Structure des dossiers

Demander approbation explicite.
**NE PAS CONTINUER sans réponse.**

SI changements → retour au DESIGNER

SI approuvé → continuer

### 4. IMPLEMENTER
Créer :
- Structure des dossiers
- Fichiers de config (build, lint, format)
- CLAUDE.md du projet (depuis templates/project-CLAUDE.md)
- README.md
- Code de base (entry point, modules principaux)
- Structure de tests

### 5. REVIEWER
Valider :
- Cohérence de la structure
- Scalabilité
- Mauvaises décisions initiales

### 6. FIX LOOP — max 3 itérations

SI CRITICAL issues :
- Appeler IMPLEMENTER avec les corrections
- Appeler REVIEWER
- Incrémenter le compteur

SI compteur > 3 :
- STOP
- Escalader à l'utilisateur

SI seulement IMPORTANT ou MINOR :
- Continuer mais lister dans l'output final

### 7. TESTER
Définir :
- Comment valider le setup initial
- Premiers scénarios de test

---

## OUTPUT FINAL

- Structure du projet créée
- Instructions de setup
- Code initial
- Prochaines étapes recommandées
