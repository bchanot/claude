# lib/pack-census-fragments.jq — fragment invariants (lib/pack-census.sh).
# $m = manifests [{id,on}], $deny = space-separated profiles that deny the
# two higgsfield connectors; inputs = lib/profiles/*.json. Prints RED lines,
# and WARN lines for a pack id with no manifest.
def name_of: input_filename | sub(".*/"; "");
def dn: [(.deniedMcpServers // [])[] | .serverName] | sort;
[inputs | {f: name_of, frag: .}] as $all
| ($all[] | select(.f == "full.json") | .frag) as $full
| ($full.enabledPlugins | keys) as $keys
| ($deny | split(" ") | map(. + ".json")) as $deny_files
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
  ( ["model-router@skills-dir", "security-guidance@claude-code-plugins"][]
    | select($g.enabledPlugins[.] != true)
    | "RED lib/profiles/\($f): \(.) must be true" ),
  ( ["example-skills@anthropic-agent-skills", "brightdata-plugin@synced"][]
    | select($g.enabledPlugins[.] != false)
    | "RED lib/profiles/\($f): \(.) must be false" ),
  ( (["claude.ai higgsfield", "claude.ai Higgsfield AI"] | sort) as $both
    | if (($deny_files | index($f)) != null) and (($g | dn) != $both)
      then "RED lib/profiles/\($f): must deny both higgsfield connectors"
      elif (($deny_files | index($f)) == null) and (($g | dn) | length) > 0
      then "RED lib/profiles/\($f): must deny no connector"
      else empty end ),
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
