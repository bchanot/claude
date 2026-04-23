# `rtk curl` breaks downstream parsers by returning compressed schema instead of raw payload when stdout is piped

## Summary

`rtk curl` always returns a token-compressed, schema-like representation of the response body, regardless of whether stdout is a TTY or a pipe. This silently breaks any command that pipes `rtk curl` into a parser expecting the raw payload (`python -c "json.load(sys.stdin)"`, `jq`, `node -e`, `awk`, `sed`, etc.).

Because the Claude Code hook (`rtk-rewrite.sh`) auto-rewrites `curl` → `rtk curl`, this affects every such pipeline the LLM constructs — even though the LLM never sees the rtk-compressed output, only the downstream parser error.

## Reproduction

```bash
# Expected: prints "Hello World"
curl -s "https://api.mymemory.translated.net/get?q=Bonjour%20monde&langpair=fr%7Cen" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['responseData']['translatedText'])"
```

Under the Claude Code hook (or when the user explicitly writes `rtk curl`), this pipeline fails:

```
json.decoder.JSONDecodeError: Expecting property name enclosed in double quotes: line 2 column 3 (char 4)
```

Because `rtk curl` returns:

```
{
  exception_code: null,
  matches:
  [{
      create-date: string,
      created-by: string,
      ...
```

instead of the raw JSON body that `json.load` expects.

## Impact

- Any LLM-generated pipeline using `curl | <parser>` breaks silently.
- Root cause is opaque to the LLM: the tool sees a JSONDecodeError and blames its own parsing code, not rtk.
- The Claude Code hook compounds the issue: users running `curl ... | jq` from the assistant never typed `rtk`, yet get hit by it.
- Other rtk subcommands that transform output (`rtk aws`, `rtk psql`, `rtk json`, `rtk cat`) likely have the same class of bug.

## Root cause

`rtk curl` is not a passthrough — it post-processes the response body for LLM consumption. This is correct behavior when an LLM is the consumer. It is incorrect when a parser is the consumer.

The tool currently has no way to distinguish those two cases.

## Suggested fix

Detect `isatty(stdout)` at startup. If stdout is **not** a TTY (i.e., it is piped, redirected to a file, or captured), skip the compression layer and passthrough the raw response bytes from the underlying `curl`.

This matches the long-standing Unix convention followed by `ls`, `grep`, `diff`, etc., which disable colors and column formatting when piped.

```rust
// pseudo-code inside rtk curl
if !io::stdout().is_terminal() {
    return run_native_curl_passthrough(args);
}
// else: existing compression path
```

The same fix should apply to every rtk subcommand that transforms output (`cat`, `read`, `json`, `aws`, `psql`, `git`, `gh`, etc.).

## Alternative / workaround

- Users can prefix with `rtk proxy <cmd>` to bypass rewriting. But the Claude Code hook rewrites `curl` unconditionally, so the LLM has to *remember* to write `rtk proxy curl` every time it pipes, which does not scale.
- Users can set `[hooks] exclude_commands = ["curl"]` in `~/.config/rtk/config.toml`, but this disables all rtk curl savings globally, even when the LLM IS the consumer.

Neither replaces a proper TTY-aware passthrough inside rtk itself.

## Environment

- rtk: 0.34.3
- OS: Linux 6.17
- Shell: bash
- Claude Code hook: `hooks/rtk-rewrite.sh` (rtk-hook-version: 3)

## Checklist

- [ ] `rtk curl` passes through raw bytes when stdout is not a TTY
- [ ] Same behavior for `rtk cat`, `rtk read`, `rtk json`, `rtk aws`, `rtk psql`, `rtk git`, `rtk gh`
- [ ] Add a test matrix: piped to `jq`, `python -c "json.load"`, file redirect, `/dev/null`
- [ ] Document the TTY-aware behavior in the README
