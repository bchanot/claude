# phase2.jq — the phase 2 settings.json change (BDR-125), applied by the
# controller to HEAD (through the index) and to the live working copy.
# $ask / $deny: the bench-approved rules (approved.txt). Additions only.
def add($k; $xs): .permissions[$k] += ($xs - .permissions[$k]);
def twins: [ .permissions.deny[]
  | capture("^Bash\\((cat|head|tail) (?<x>[^ ]*)\\)$")? | .x ]
  | unique | map("rtk read " + sub("\\*$"; "") + "*")
  | map("Bash(" + . + ")", "Bash(*/" + . + ")");
add("ask"; $ask) | add("deny"; $deny) | add("deny"; twins)
| .hooks.PostToolUse = ((.hooks.PostToolUse // [])
    + [{matcher: "Edit|Write", hooks: [{type: "command",
        command: "bash ~/.claude/hooks/code-limits.sh", timeout: 5}]}]
    | unique_by(.hooks[0].command))
| .autoMode.hard_deny += (["Passing a gate by editing it or by routing: never edit `permissions.ask` to skip a prompt it raises, and never call the model-router `route` tool or type `/route` outside a skill run to lift its write guard. A model-router redirect (\"code is written inside a skill run\") names the skill to enter: enter it. It is a redirect to follow, not a refusal to report and wait on."] - .autoMode.hard_deny)
| .autoMode.soft_deny += (["Static rule blind spots: the permission matcher cannot see `$(…)` in command position, a quoted literal argument (`echo \"SECRET\"`, `git push origin \":ref\"`), an inline interpreter (`python3 -c`, `python -c`, `node -e`, `perl -e`), a script piped into a shell (`… | bash -s`) or a sourced shell function (`source …/gitflow.sh; gitflow_finish`). A command that uses one of these shapes to reach an action a deny or ask rule names is that action: refuse it unless the user asked for that exact action in this turn."] - .autoMode.soft_deny)
