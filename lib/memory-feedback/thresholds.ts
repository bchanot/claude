// lib/memory-feedback/thresholds.ts: phase 4d gate numbers and threshold
// actions, fixed before the data (BDR-100: one file; the reader and a
// future /prune-memory step read it). Spec §4.
export const DAY_MS = 86400000
export const GATE_DAYS = 35 // the 5-week cap from the gate clock start
export const PROMPT_GATE_N = 20 // labelled injected prompt asks
export const TOOL_GATE_N = 10 // labelled tool injections

export const T = {
  promptKeep: 0.64, // relevant / labelled entries (4c baseline 14/22)
  triggerFloor: 0.5, // worst trigger kind under this gets tightened
  thirdPick: 0.4, // 3rd pick precision under this caps picks at 2
  lateShare: 0.25, // timeout + paused among asks with candidates
  msP90: 2500, // rerank p90 under this lowers RERANK_MS
  toolKeep: 0.5, // tool precision under this narrows the match
  missShare: 1 / 3, // sampled asks with a miss, at or over this
  noisyHits: 3, // injected this often and never relevant: noisy
  promoteHits: 3, // relevant this often...
  promoteSessions: 2, // ...in this many sessions: promotion candidate
} as const
