---
name: ship-feature
description: Implémente une feature end-to-end via orchestration multi-agents. Analyse → Design → Validation → Implémentation → Review → Tests.
argument-hint: <description de la feature à implémenter>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATEUR : SHIP FEATURE

Charge et applique strictement :
- .claude/agents/analyzer.md
- .claude/agents/designer.md
- .claude/agents/implementer.md
- .claude/agents/reviewer.md
- .claude/agents/tester.md

---

## FEATURE

$ARGUMENTS

---

## WORKFLOW

### 1. ANALYZER
Analyser le contexte existant pertinent à la feature.

### 2. DESIGNER
Concevoir la solution sur la base de l'analyse.

### 3. VALIDATION GATE — STOP OBLIGATOIRE
- Présenter le design clairement à l'utilisateur
- Demander une approbation explicite
- **NE PAS CONTINUER sans réponse**

SI changements demandés :
- Appeler DESIGNER avec le feedback
- Répéter la validation

SI approuvé → continuer

### 4. IMPLEMENTER
Implémenter selon le design validé.

### 5. REVIEWER
Review stricte du code produit.

### 6. FIX LOOP — max 3 itérations

SI CRITICAL issues :
- Appeler IMPLEMENTER avec les corrections
- Appeler REVIEWER
- Incrémenter le compteur

SI compteur > 3 :
- STOP
- Escalader à l'utilisateur avec les issues bloquantes

SI seulement IMPORTANT ou MINOR :
- Continuer mais les lister dans l'output final

### 7. TESTER
Générer et exécuter les tests de la feature.

---

## RULES

- Ne jamais sauter l'analyse
- Ne jamais sauter la validation
- Ne jamais implémenter sans approbation
- Garder les agents isolés dans leurs responsabilités
- Appliquer les normes CLAUDE.md strictement

---

## OUTPUT FINAL

- Design validé
- Implémentation finale
- Résumé de la review
- Plan de tests et résultats
