#!/usr/bin/env bash
# lib/tests/memory-feedback.test.sh — the bun unit suite of
# lib/memory-feedback (phase 4d reader, labels, metrics, transcripts).
# Fails when bun is absent: it never passes vacuously.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
command -v bun >/dev/null 2>&1 || { echo "FAIL bun not on PATH"; exit 1; }
cd "$ROOT/lib/memory-feedback" || exit 1
bun test 2>&1
