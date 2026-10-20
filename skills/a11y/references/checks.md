# Accessibility checks

Rule ids the scanner emits, what each proves, and the fix. Severity is the
default; a judged hit can be a false positive.

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| A11Y-IMG-ALT | FAIL | `img` or `Image` without `alt` | describe it, or `alt=""` if decorative |
| A11Y-FIELD-LABEL | FAIL | native input, select, textarea with no label | `label for`, wrapping label or `aria-label` |
| A11Y-CLICK-NO-KEYBOARD | FAIL | click handler on a div or span lacking role, tabindex or key handler | use a `button` |
| A11Y-FOCUS-OUTLINE | FAIL / WARN | focus outline removed; WARN when a `:focus-visible` style exists elsewhere | style `:focus-visible` instead |
| A11Y-TABINDEX-POSITIVE | WARN | `tabindex` above 0 | use 0 or -1 and fix the DOM order |

## Blind spots

The scanner is regex over markup and styles. It cannot see:

- keyboard traps, focus order, a modal that keeps or loses focus, color
  contrast: the `--live` walk covers the first three, `/web-validate` the
  fourth
- a label wired through `aria-labelledby` to an element in another file
- components whose markup is built at runtime, minified bundles, anything
  over 1 MB
- `.astro` files for the click rule (never flagged)

By design the scanner ignores: fields that are never rendered (`hidden`,
`display: none`), click handlers that only stop propagation or sit on
`role="presentation"`, focus styles that swap the outline for a border or
shadow, and `img` tags inside comments.

## Fix loop: oracles and re-pass

Every accepted fix is proven by the scanner itself, never by the executor's
word. Two check modes replace the report and its exit code:

| Mode | Passes when | Marker | Used by |
|---|---|---|---|
| `--assert-absent RULE:path,...` | none of these FAIL/WARN pairs remains, the domain was scanned, the tree is not empty | `A11Y-CLEAR <n>` | a contract `CHECK:` run by `lib/gates.sh` (GATE 0) |
| `--baseline before.json` | no FAIL/WARN hit appeared since the earlier `--json` run | `A11Y-NO-NEW` | STEP 9 re-pass |

Pairs match on rule and file, not line: a fix moves lines. An empty tree
fails the assertion, because absence there proves nothing. Run every oracle
once before the fix: it must fail. The baseline lists `FIXED` and `NEW`
pairs with their hit counts; a `NEW` hit after a fix is a regression.
