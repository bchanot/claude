# lib/pack-census-fragments.jq — fragment invariants (lib/pack-census.sh).
# $m = manifests [{id,on}]; inputs = lib/profiles/*.json. Prints RED lines,
# and WARN lines for a pack id with no manifest. A fragment may carry only
# the top-level keys lib/profile.sh reads (an allowlist).
def name_of: input_filename | sub(".*/"; "");
def dn: [(.deniedMcpServers // [])[] | .serverName] | sort;
[inputs | {f: name_of, frag: .}] as $all
| ($all[] | select(.f == "full.json") | .frag) as $full
| ($full.enabledPlugins | keys) as $keys
| ($m | map({key: .id, value: .on}) | from_entries) as $mdef
| ($m | map(.id)) as $mids
| ( [$all[] | {f, ep: .frag.enabledPlugins, d: (.frag | dn)}] as $s
  | ($s | to_entries[]) as $e
  | $s[$e.key + 1:][] | select(.ep == $e.value.ep and .d == $e.value.d)
  | "RED lib/profiles/\($e.value.f) and \(.f) are identical fragments" ),
  ( $all[]
| .f as $f | .frag as $g
| ( if ($g.enabledPlugins | keys) != $keys
    then "RED lib/profiles/\($f): key set differs from full.json"
    else empty end ),
  ( ($g | keys)
      - ["enabledPlugins", "deniedMcpServers", "disableClaudeAiConnectors",
         "model"]
    | select(length > 0)
    | "RED lib/profiles/\($f): unknown top-level key(s) \(join(", "))" ),
  ( ["model-router@skills-dir", "security-guidance@claude-code-plugins"][]
    | select($g.enabledPlugins[.] != true)
    | "RED lib/profiles/\($f): \(.) must be true" ),
  ( ["example-skills@anthropic-agent-skills", "brightdata-plugin@synced"][]
    | select($g.enabledPlugins[.] != false)
    | "RED lib/profiles/\($f): \(.) must be false" ),
  ( if $f == "full.json" then
      ($mdef | to_entries[] | select($g.enabledPlugins[.key] != .value)
       | "RED lib/profiles/full.json: \(.key) is \($g.enabledPlugins[.key])"
         + " but the manifest default is \(.value)")
    else empty end ),
  ( $g.enabledPlugins | keys[]
    | select(startswith("pack-") and endswith("@skills-dir")
             and (. as $k | $mids | index($k) == null))
    | sub("@skills-dir$"; "") as $n
    | "WARN lib/profiles/\($f): names \($n) with no skills/\($n)/" ) )
