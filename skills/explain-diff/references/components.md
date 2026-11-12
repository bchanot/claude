# Components for an explain-diff page

Every snippet below is styled by `assets/template.html`. Copy, then replace
the sample content. Keep the class names: the stylesheet and the checker
know them. Sample text is in English; write yours in the page language.

## Skippable deep background

The newcomer's tour of the system goes in a collapsible block, so a reader
who knows it can jump straight to the narrow background.

```html
<details class="deep">
  <summary>How the hint service works <span class="hint">(skip if you
    know it)</span></summary>
  <p>…</p>
</details>
```

## Callouts

Three kinds: `concept` (a definition or key idea), `edge` (an edge case
worth remembering), `risk` (what can still go wrong, or a follow-up).

```html
<aside class="callout concept">
  <p class="callout-title">Lazy guest</p>
  <p>A visitor who has not played yet has no session row …</p>
</aside>
<aside class="callout edge">
  <p class="callout-title">Edge case: session creation fails</p>
  <p>…</p>
</aside>
<aside class="callout risk">
  <p class="callout-title">Not covered by this change</p>
  <p>…</p>
</aside>
```

## Flow of components

Nodes left to right, an `arrow` between each pair. Its label carries the
example data that travels (a call, a payload, a return value). `hl` marks
the component the change touches. On a phone the flow turns vertical.

```html
<figure class="diagram">
  <div class="flow">
    <div class="node"><span class="node-title">Browser</span>
      <span class="node-sub">guest g-42, no session</span></div>
    <div class="arrow">ensureGuest()</div>
    <div class="node hl"><span class="node-title">fetchHint</span>
      <span class="node-sub">new: session first</span></div>
    <div class="arrow">rpc hint(day=12)</div>
    <div class="node"><span class="node-title">Database</span>
      <span class="node-sub">auth-gated RPC</span></div>
  </div>
  <figcaption>After the fix: the session exists before the hint call.
  </figcaption>
</figure>
```

A return value travels back through the label of the same arrow
(`hint(day=12) → "starts with B"`) or through a second flow below.

## Row of states

Same markup with `state` nodes; `hl` marks the state the change adds.

```html
<div class="flow">
  <div class="node state"><span class="node-title">running</span></div>
  <div class="arrow">crash ×3</div>
  <div class="node state hl"><span class="node-title">stopped</span>
    <span class="node-sub">new: final</span></div>
</div>
```

## Before and after

```html
<div class="compare">
  <div class="pane before">
    <p class="pane-label">Before</p>
    <p>…</p>
  </div>
  <div class="pane after">
    <p class="pane-label">After</p>
    <p>…</p>
  </div>
</div>
```

## Simplified UI mock

For UI changes: draw only what the user sees that matters, as boxes.
`mark` outlines the element the change affects. Put two mocks inside the
panes of a `compare` block for a before and after view.

```html
<div class="mock">
  <div class="mock-bar">Daily puzzle · day 12</div>
  <div class="mock-body">
    <p>Find the word in 6 tries.</p>
    <div class="mock-field">B _ _ _ _</div>
    <div class="mock-button">Hint</div>
    <div class="mock-alert mark">Hint unavailable</div>
  </div>
</div>
```

`mock-alert ok` gives the success colour.

## Toy data

```html
<div class="table-wrap">
  <table class="data">
    <thead><tr><th>Visitor</th><th>Session</th><th>Hint</th></tr></thead>
    <tbody>
      <tr><td>g-42</td><td>none</td><td>refused</td></tr>
    </tbody>
  </table>
</div>
```

## Code excerpt and diff

Show only the lines that matter, with the `path:line` above. Escape `<`,
`>` and `&` in every code block.

```html
<figure>
  <span class="path">apps/web/src/game/daily.ts:31</span>
  <pre><code>export async function fetchDailyHint(day: number) {
  const ok = await ensureGuestSession();
  if (!ok) return null;
}</code></pre>
  <figcaption>The session comes first; a failure ends in null.</figcaption>
</figure>
```

A diff block holds raw unified-diff lines; the template's script colours
the `+`, `-` and `@@` lines. Keep the leading `+` / `-` / space.

```html
<figure>
  <span class="path">apps/web/src/game/daily.ts</span>
  <pre class="diff">@@ -28,6 +28,9 @@ export async function fetchDailyHint
 export async function fetchDailyHint(day: number) {
+  const ok = await ensureGuestSession();
+  if (!ok) return null;
   return rpc(&quot;hint&quot;, { day });</pre>
</figure>
```

## Quiz data

The template renders the quiz from the JSON block `quiz-data`. Five
questions, three or four options each, exactly one `"correct": true`, and a
`why` on every option. Backticks in any string render as inline code. Plain
text only, no HTML; write `<\/` for any `</` inside a string.

```json
[
  {
    "q": "A guest with no session asks for a hint. What runs first?",
    "options": [
      {"text": "The hint RPC", "correct": false,
       "why": "That was the bug: the RPC refused a caller with no session."},
      {"text": "`ensureGuestSession()`", "correct": true,
       "why": "The fetcher now creates the session, then calls the RPC."},
      {"text": "A page reload", "correct": false,
       "why": "Nothing reloads; the fix stays inside the fetcher."}
    ]
  }
]
```

Labels on `#quiz-root` follow the page language. `{n}` and `{total}` in the
score label are filled by the script.

| Placeholder | English | French |
|---|---|---|
| `{{QUIZ_RIGHT}}` | Right. | Exact. |
| `{{QUIZ_WRONG}}` | Not quite. | Pas tout à fait. |
| `{{QUIZ_SCORE}}` | Score: {n} out of {total} | Score : {n} sur {total} |
