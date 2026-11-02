# lib/profile-state.jq — effective profile state of one project and
# conversation, in one pass (lib/profile.sh `current`, `unset`).
# Args: $u $p $l $f raw settings files (user, project, local, --settings;
# "" when absent), $cj raw ~/.claude.json, $m manifests [{id,on}],
# $mode "plain" | "human" | "json", $proj project dir, $flagname CLAUDE_PROFILE
# or "-", $hasflag "1" when a --settings file is in force.
# inputs = lib/profiles/*.json (one fragment per file).
def parse: try fromjson catch {};
def name_of: input_filename | sub(".*/"; "") | sub("\\.json$"; "");
def ep: (.enabledPlugins // {});
def dn: [(.deniedMcpServers // [])[] | .serverName];
def onoff: if . then "on" else "off" end;
def is_pack: startswith("pack-") and endswith("@skills-dir");
def short: sub("@skills-dir$"; "");
def src_word($s):
  if $s.source == "flag" then "conv \($s.flag)" else $s.source end;
def listing($plugins; $on):
  [$plugins | to_entries[] | select(.value == $on) | .key | short]
  | if length == 0 then "none" else join(" ") end;

[inputs | {name: name_of, frag: .}] as $profiles
| ($u | parse) as $U | ($p | parse) as $P
| ($l | parse) as $L | ($f | parse) as $F
| ([$profiles[].frag | ep | keys[]] | unique) as $ids
| ($m | map({key: .id, value: .on}) | from_entries) as $mdef
| ($ids | map({key: ., value: ($mdef[.]
      // (if endswith("@skills-dir") and (is_pack | not) then true
          else false end))}) | from_entries) as $d
| (($d + ($U|ep) + ($P|ep) + ($L|ep) + ($F|ep))
   | with_entries(select(.key as $k | $d | has($k)))) as $plugins
| ((($U|dn) + ($P|dn) + ($L|dn) + ($F|dn)) | unique) as $denied
| ([$U, $P, $L, $F] | any(.disableClaudeAiConnectors == true)) as $all
| ($F.model // $L.model // $P.model // $U.model // "-") as $model
| (if ($F | has("model")) then "flag" elif ($L | has("model")) then "local"
   elif ($P | has("model")) then "project"
   elif ($U | has("model")) then "user" else "-" end) as $msrc
| (if $hasflag == "1" then "flag"
   elif ((($L|ep) | length) + (($L|dn) | length)) > 0 then "local"
   else "default" end) as $src
| (try ($cj | fromjson | .projects[$proj].disabledMcpServers // []
        | if length == 0 then "-" else join(",") end)
   catch (if $cj == "" then "-" else "unknown" end)) as $off
| ([$profiles[] | select((.frag | ep) == $plugins
       and ((.frag | dn | sort) == ($denied | sort)) and ($all | not))
    | .name] | .[0] // "custom") as $name
| {name: $name, source: $src, flag: $flagname, plugins: $plugins,
   denied: $denied, all_denied: $all, model: $model, model_source: $msrc,
   mcp_off: $off} as $s
| if $mode == "json" then $s
  elif $mode == "plain" then
    ( ["profile=\($s.name)", "source=\($s.source)", "flag=\($s.flag)"]
      + [$plugins | to_entries | sort_by(.key)[] | select(.key | is_pack)
         | "\(.key | short)=\(.value | onoff)"]
      + [$plugins | to_entries | sort_by(.key)[]
         | select(.key | is_pack | not) | "plugin:\(.key)=\(.value | onoff)"]
      + [$denied[] | "connector:\(.)=denied"]
      + (if $all then ["connector:*=denied"] else [] end)
      + ["model=\($s.model)", "model-source=\($s.model_source)",
         "mcp-off=\($s.mcp_off)"] ) | .[]
  else
    ( [ (if $s.mcp_off != "-"
         then "profile: custom (off: \($s.mcp_off)) [\(src_word($s))]"
         else "profile: \($s.name) [\(src_word($s))]" end),
        "  on : \(listing($plugins; true))",
        "  off: \(listing($plugins; false))",
        "  connectors denied: \(if $all then "all"
           elif ($denied | length) == 0 then "none"
           else ($denied | join(", ")) end)",
        "  model: \($s.model) (\($s.model_source))" ] ) | .[]
  end
