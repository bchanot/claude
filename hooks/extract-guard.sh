#!/usr/bin/env bash
# extract-guard.sh — PreToolUse (Bash|Monitor): refuse a package/archive
# extraction into / or a system directory (usr-merge incident: dpkg -x into
# / replaced /bin /lib symlinks with real dirs). Watched: dpkg -x, dpkg-deb
# -x/-R, tar x, unzip, cpio -i, recursive cp. System dirs: / /usr /etc /bin
# /sbin /lib* /boot /opt /var /srv /root /sys /proc /dev (not /var/tmp,
# /var/folders, $HOME). An unresolvable destination ($VAR, $(..)) is refused.
#
# Deny form: JSON on stdout, exit 0 (shape of hooks/push-guard.sh, BDR-111).
# Silent on every allowed command. jq, awk, grep, sed, tr or wc missing: one
# stderr warning, allow. A command that names no watched word (also with
# quotes and backslashes removed) never reaches awk; past that prefilter a
# command over 256 KiB or an awk failure denies (fail closed). The cap bounds
# the awk tokenizer, which rebuilds a word by concatenation.
#
# The parser is one POSIX awk program (bash 3.2 safe). Its tokenizer is
# adapted from push-guard.sh simple_cmds at fe7d5cd: newlines inside quotes
# stay in the word, redirections and `<<<` are words of their own, `$(..)`
# and backticks and heredoc bodies are queued for a scan of their own, and
# every quoted word holding a blank is re-scanned (no carrier list: ssh,
# vaas-cli ssh, bash -c, sudo sh -c, find -exec all fall out of it).
#
# MISSES: a destination built outside the text (script file, Makefile, alias,
# variable set in an earlier call); old-style tar `C` letter (tar xfC a
# /usr), --dir= abbreviations, --one-top-level=; a tool name built by $'\x74'
# escapes (the prefilter strips only quotes and backslashes) or by expansion
# (t$'a'r, t$''ar, t$"a"r, t${x}ar, an empty $() or backticks inside a
# name): mostly stopped by the prefilter, the soft_deny line is the net;
# archive members escaping a safe -C (../../usr, -P); a cd to a system dir in a
# remote shell then an extraction with no destination; option values read as
# tool words.
# ACCEPTED FALSE POSITIVES: text holding a complete extraction into a system
# dir, `dpkg -x <word>` with no directory, a glob or brace destination, and
# a quoted script run after a cd to a system dir (cd / && ssh vm "tar xf a":
# the script inherits the caller's directory; a ( .. ) subshell restores
# it). The autoMode soft_deny rule is the net.
set -u

for t in jq awk grep sed tr wc; do
  command -v "$t" >/dev/null 2>&1 || {
    echo "extract-guard: $t missing, guard inactive" >&2
    exit 0
  }
done

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

SOH=$'\001'
WATCHED='(^|[^[:alnum:]_.-])(dpkg|dpkg-deb|tar|bsdtar|gtar|unzip|cpio|cp)([^[:alnum:]_-]|$)'
hit() { printf '%s' "$1" | grep -qE "$WATCHED"; }
# second look with quotes, backslashes and backslash-newline removed, so
# t'a'r, "t"ar, ta\<newline>r and $'tar' still reach the parser
flat=$(printf '%s' "$cmd" | tr '\n' '\001' | sed "s/\\\\$SOH//g" \
  | tr -d "'\"\\\\")
hit "$cmd" || hit "$flat" || exit 0

IFS= read -r -d '' PROG <<'AWK' || true
function base(s) { sub(/^.*\//, "", s); return s }
function hasblank(w) { return index(w, " ") || index(w, "\t") || index(w, "\n") }
function deny(msg) { print msg; exit 0 }
function toobig() {
  deny("extract-guard: refused: command too large to check; run it yourself if it is safe: ! <command> (CLAUDE.md § Destructive tools & data loss)")
}

function enqueue(t, d, dir) {
  if (d > 3) {
    if (t ~ WRE) deny("extract-guard: refused: nesting too deep to check a command that names an extraction tool; run it yourself if it is safe: ! <command> (CLAUDE.md § Destructive tools & data loss)")
    return
  }
  if (++nenq > 300) toobig()
  qn++; QT[qn] = t; QD[qn] = d; QDIR[qn] = dir
}

function endword() {
  if (have) { nrw++; RW[nrw] = word; RQ[nrw] = wq }
  word = ""; have = 0; wq = 0
}
function endcmd() { if (nrw) process(); nrw = 0 }

# closing quote q of the quote opened at k; n + 1 when unclosed
function qend(k, q,   m, ch) {
  for (m = k + 1; m <= n; m++) {
    ch = substr(txt, m, 1)
    if (q == "\"" && ch == "\\") { m++; continue }
    if (ch == q) return m
  }
  return n + 1
}

# $( ... ) at i: balanced inner text queued, the word keeps a "$" marker
function subst(   k, dp, ch) {
  dp = 1; k = i + 2
  while (k <= n && dp > 0) {
    ch = substr(txt, k, 1)
    if (ch == "'" || ch == "\"") k = qend(k, ch) + 1
    else if (ch == "\\") k += 2
    else { if (ch == "(") dp++; else if (ch == ")") dp--; k++ }
  }
  if (dp == 0) { enqueue(substr(txt, i + 2, k - i - 3), cdep + 1, DIR); i = k }
  else { enqueue(substr(txt, i + 2), cdep + 1, DIR); i = n + 1 }
  word = word "$"; have = 1
}

# backtick command substitution at i
function bq(   k, ch) {
  for (k = i + 1; k <= n; k++) {
    ch = substr(txt, k, 1)
    if (ch == "\\") { k++; continue }
    if (ch == "`") break
  }
  enqueue(substr(txt, i + 1, k - i - 1), cdep + 1, DIR)
  word = word "$"; have = 1; i = k + 1
}

function dquote(   c, d) {
  while (i <= n) {
    c = substr(txt, i, 1)
    if (c == "\"") { i++; return }
    d = substr(txt, i + 1, 1)
    if (c == "\\" && i < n && index("\"\\$`\n", d)) {
      if (d != "\n") word = word d
      i += 2
    } else if (c == "$" && d == "(") subst()
    else if (c == "`") bq()
    else { word = word c; i++ }
  }
}

# $'...' at i (ANSI-C quoting): content kept, \n \t \xHH \NNN decoded
function ansi(   c, d) {
  have = 1; wq = 1; i += 2
  while (i <= n) {
    c = substr(txt, i, 1)
    if (c == "'") { i++; return }
    if (c != "\\") { word = word c; i++; continue }
    d = substr(txt, i + 1, 1); i += 2
    if (d == "n") word = word "\n"
    else if (d == "t") word = word "\t"
    else if (d == "x" || d ~ /^[0-7]$/) word = word ansi_num(d)
    else word = word d
  }
}

# up to two more digits after \x (hex) or the octal digit d
function ansi_num(d,   rad, left, v, dg) {
  rad = (d == "x") ? 16 : 8; left = 2
  v = (d == "x") ? -1 : d + 0
  while (left > 0 && i <= n) {
    dg = index("0123456789abcdef", tolower(substr(txt, i, 1)))
    if (dg == 0 || dg > rad) break
    v = (v < 0 ? 0 : v) * rad + dg - 1; i++; left--
  }
  return v <= 0 ? "" : sprintf("%c", v)
}

function quoted(c,   j, d) {
  if (c == "'") {
    have = 1; wq = 1
    j = qend(i, "'")
    word = word substr(txt, i + 1, j - i - 1); i = j + 1
  } else if (c == "\"") { have = 1; wq = 1; i++; dquote()
  } else if (c == "`") bq()
  else {
    d = substr(txt, i + 1, 1)
    if (i < n && d != "\n") { word = word d; have = 1; wq = 1 }
    i += 2
  }
}

# heredoc delimiter after << (quotes and backslashes removed)
function read_delim(   q, d, ch) {
  if (substr(txt, i, 1) == "-") i++
  while (substr(txt, i, 1) == " " || substr(txt, i, 1) == "\t") i++
  d = ""
  while (i <= n) {
    ch = substr(txt, i, 1)
    if (index(" \t\n;&|()<>", ch)) break
    if (ch == "'" || ch == "\"") {
      q = ch; i++
      while (i <= n && substr(txt, i, 1) != q) { d = d substr(txt, i, 1); i++ }
      i++; continue
    }
    if (ch == "\\") { d = d substr(txt, i + 1, 1); i += 2; continue }
    d = d ch; i++
  }
  hd[++nh] = d
}

# heredoc bodies start after the newline that ended the command line
function read_heredocs(   k, e, ln, chk, body) {
  for (k = 1; k <= nh; k++) {
    body = ""
    while (i <= n) {
      for (e = i; e <= n && substr(txt, e, 1) != "\n"; e++) ;
      ln = substr(txt, i, e - i); i = e + 1
      chk = ln; sub(/^\t+/, "", chk)
      if (chk == hd[k]) break
      body = body ln "\n"
    }
    enqueue(body, cdep + 1, DIR)
  }
  nh = 0
}

# a redirection operator becomes a word of its own (fd prefix kept)
function redir(   c, d, op) {
  if (!(have && !wq && word ~ /^[0-9]+$/)) endword()
  c = substr(txt, i, 1); d = substr(txt, i + 1, 1)
  if (c == "&") { op = "&>"; i += 2; if (substr(txt, i, 1) == ">") { op = op ">"; i++ } }
  else {
    op = c; i++
    if (c == ">" && (d == ">" || d == "|")) { op = op d; i++ }
    else if (d == "&") {
      op = op d; i++
      while (i <= n && index("0123456789-", substr(txt, i, 1))) { op = op substr(txt, i, 1); i++ }
    } else if (c == "<" && d == ">") { op = op d; i++ }
  }
  word = word op; have = 1; endword()
}

function op_item(c) {
  if (c == "(") { endword(); endcmd(); SD[++sdn] = DIR; i++ }
  else if (c == ")") { endword(); endcmd(); if (sdn > 0) DIR = SD[sdn--]; i++ }
  else if (c == ";" || c == "|") { endword(); endcmd(); i++ }
  else if (c == "&" && substr(txt, i + 1, 1) != ">") { endword(); endcmd(); i++ }
  else if (c == "<" && substr(txt, i + 1, 2) == "<<") {
    endword(); word = "<<<"; have = 1; endword(); i += 3
  } else if (c == "<" && substr(txt, i + 1, 1) == "<") { endword(); i += 2; read_delim() }
  else redir()
}

function token(   c) {
  c = substr(txt, i, 1)
  if (c == "'" || c == "\"" || c == "\\" || c == "`") quoted(c)
  else if (c == "$" && substr(txt, i + 1, 1) == "'") ansi()
  else if (c == "$" && substr(txt, i + 1, 1) == "\"") { i++; quoted("\"") }
  else if (c == "$" && substr(txt, i + 1, 1) == "(") subst()
  else if (c == "\n") { endword(); endcmd(); i++; if (nh) read_heredocs() }
  else if (c == " " || c == "\t") { endword(); i++ }
  else if (c == "#" && !have) { while (i <= n && substr(txt, i, 1) != "\n") i++ }
  else if (index(";|()<>&", c)) op_item(c)
  else { word = word c; have = 1; i++ }
}

function scan(t, d, dir) {
  txt = t; n = length(t); i = 1; cdep = d; DIR = dir
  word = ""; have = 0; wq = 0; nrw = 0; nh = 0; sdn = 0
  while (i <= n) token()
  endword(); endcmd()
}

# absolute normalized path; "$" = unresolvable (also glob and brace); "" = relative without a cwd
function norm(p,   nc, k, c, sp, out) {
  if (p ~ /^~(\/|$)/) p = "/HOME" substr(p, 2)
  else if (p ~ /^[$]HOME(\/|$)/) p = "/HOME" substr(p, 6)
  else if (p ~ /^[$][{]HOME[}](\/|$)/) p = "/HOME" substr(p, 8)
  if (substr(p, 1, 1) == "~" || index(p, "$") || index(p, "`")) return "$"
  if (p ~ /[[*?]/ || p ~ /[{][^}]*(,|[.][.])[^}]*[}]/) return "$"
  if (substr(p, 1, 1) != "/") {
    if (DIR == "" || DIR == "$") return DIR
    p = DIR "/" p
  }
  nc = split(p, parts, "/"); sp = 0
  for (k = 1; k <= nc; k++) {
    c = parts[k]
    if (c == "" || c == ".") continue
    if (c == "..") { if (sp > 0) sp--; continue }
    stack[++sp] = c
  }
  out = ""
  for (k = 1; k <= sp; k++) out = out "/" stack[k]
  return out == "" ? "/" : out
}

# 1 system, 2 unresolvable, 0 fine
function is_system(p,   q, nc) {
  q = norm(p)
  if (q == "$") return 2
  if (q == "") return 0
  if (q == "/") return 1
  nc = split(q, parts, "/")
  if (parts[2] == "HOME") return 0
  if (parts[2] == "var" && (parts[3] == "tmp" || parts[3] == "folders")) return 0
  return (parts[2] in SYS) ? 1 : 0
}

function track_cd(   j) {
  if (base(W[1]) == "popd") { DIR = ""; return }
  if (base(W[1]) != "cd" && base(W[1]) != "pushd") return
  j = 2
  while (j <= nw && W[j] ~ /^(-P|-L|-e|-@|--)$/) j++
  DIR = (j > nw || W[j] == "-") ? "" : norm(W[j])
}

# dest option at A[j]: -s <d>, -s<d>, bundle ending in s, --l <d>, --l=<d>
function dopt(j, s, l,   w, wl) {
  w = A[j]; DSKIP = 0
  if (w ~ /^-[A-Za-z]+$/ && substr(w, length(w)) == s) { DV = A[j + 1]; DSKIP = 1; return 1 }
  if (l != "") {
    if (w == "--" l) { DV = A[j + 1]; DSKIP = 1; return 1 }
    wl = "--" l "="
    if (substr(w, 1, length(wl)) == wl) { DV = substr(w, length(wl) + 1); return 1 }
  }
  if (substr(w, 1, 2) == "-" s && length(w) > 2 && w !~ /^-[A-Za-z]+$/) { DV = substr(w, 3); return 1 }
  return 0
}
function adddest() { D[++nd] = DV }

function det_tar(   j, w, x, t) {
  if (A[1] ~ /^[A-Za-z]+$/) { x = (A[1] ~ /x/); t = (A[1] ~ /t/) }
  for (j = 1; j <= na; j++) {
    w = A[j]
    if (w == "--extract" || w == "--get") x = 1
    else if (w == "--list") t = 1
    else if (w ~ /^-[A-Za-z]+$/) { if (w ~ /x/) x = 1; if (w ~ /t/) t = 1 }
    if (dopt(j, "C", "directory")) { adddest(); j += DSKIP }
  }
  ext = (x && !t)
}

function det_dpkg(b,   j, w, seen, nn, n2) {
  for (j = 1; j <= na; j++) {
    w = A[j]
    if (!seen) {
      seen = (w == "-x" || w == "-X" || w == "--extract" || w == "--vextract" || (b == "dpkg-deb" && (w == "-R" || w == "--raw-extract")))
    } else if (w !~ /^-/) { nn++; if (nn == 2) n2 = w }
  }
  if (!seen || nn == 0) return
  ext = 1
  if (nn >= 2) { DV = n2; adddest() } else absent = 1
}

function det_unzip(   j, w, lst) {
  for (j = 1; j <= na; j++) {
    w = A[j]
    if ((w ~ /^-[A-Za-z]+$/ && w ~ /[lvtzZ]/) || w ~ /^-Z/) lst = 1
    if (dopt(j, "d", "")) { adddest(); j += DSKIP }
  }
  ext = !lst
}

# -i extracts; -p (copy-pass) writes into its first non-option word
function det_cpio(   j, w, x, t, p, first) {
  for (j = 1; j <= na; j++) {
    w = A[j]
    if (w == "--extract") x = 1
    else if (w == "--pass-through") p = 1
    else if (w ~ /^-[A-Za-z]+$/) {
      if (w ~ /i/) x = 1; if (w ~ /t/) t = 1; if (w ~ /p/) p = 1
    }
    if (dopt(j, "D", "directory")) { adddest(); j += DSKIP; continue }
    if (w ~ /^-[REFHIOM]$/) j++
    else if (w !~ /^-/ && first == "") first = w
  }
  if (p && first != "") { DV = first; adddest(); ext = 1; return }
  ext = (x && !t)
}

function det_cp(   j, w, rec, last) {
  for (j = 1; j <= na; j++) {
    w = A[j]
    if (w == "--recursive" || w == "--archive") rec = 1
    else if (w ~ /^-[A-Za-z]+$/ && w ~ /[rRa]/) rec = 1
    if (dopt(j, "t", "target-directory")) { adddest(); j += DSKIP; continue }
    if (w !~ /^-/) last = w
  }
  if (!rec) return
  if (nd == 0 && last != "") { DV = last; adddest() }
  ext = (nd > 0)
}

function why(b, dest, kind) {
  gsub(/\n/, " ", dest)
  if (kind == 2)
    return "extract-guard: refused: " b " destination " dest " cannot be checked; write the literal path, run mktemp -d alone and extract into the path it prints (CLAUDE.md § Destructive tools & data loss); a real install is the user's: ! <command>"
  return "extract-guard: refused: " b " writes into system directory " dest " (CLAUDE.md § Destructive tools & data loss). List it first (dpkg -c, tar tf, unzip -l), run mktemp -d alone and extract into the literal path it prints, then use PATH or PYTHONPATH; a real system install is the user's: ! <command>"
}

function verdict(b,   j, s) {
  if (!ext) return
  if (absent) deny(why(b, "(none)", 2))
  if (nd == 0) { if (DIR == "") return; D[++nd] = DIR }
  for (j = 1; j <= nd; j++) {
    s = is_system(D[j])
    if (s) deny(why(b, D[j], s))
  }
}

function detect(b, k,   j) {
  na = 0; nd = 0; ext = 0; absent = 0
  for (j = k + 1; j <= nw; j++) A[++na] = W[j]
  A[na + 1] = ""
  if ((work += na + 1) > 300000) toobig()
  if (b ~ /^(tar|bsdtar|gtar)$/) det_tar()
  else if (b == "dpkg" || b == "dpkg-deb") det_dpkg(b)
  else if (b == "unzip") det_unzip()
  else if (b == "cpio") det_cpio()
  else det_cp()
  verdict(b)
}

# one simple command: drop redirections, track cd, run each watched tool
function process(   k, w, skip) {
  if (++nrec > 5000) toobig()
  nw = 0
  for (k = 1; k <= nrw; k++) {
    w = RW[k]
    if (hasblank(w)) enqueue(w, cdep + 1, DIR)
    if (skip) { skip = 0; continue }
    if (!RQ[k] && (w ~ /^[0-9]*[<>]/ || w ~ /^&>/)) { skip = (w ~ BARE); continue }
    if (w == "{}" || w == "+" || (RQ[k] && w == ";")) continue
    W[++nw] = w
  }
  track_cd()
  for (k = 1; k <= nw; k++) if (base(W[k]) in WATCH) detect(base(W[k]), k)
}

BEGIN {
  RS = "\001"
  split("usr etc bin sbin lib lib32 lib64 libx32 boot opt var srv root sys proc dev", sy, " ")
  for (j in sy) SYS[sy[j]] = 1
  split("dpkg dpkg-deb tar bsdtar gtar unzip cpio cp", wt, " ")
  for (j in wt) WATCH[wt[j]] = 1
  WRE = "(^|[^[:alnum:]_.-])(dpkg|dpkg-deb|tar|bsdtar|gtar|unzip|cpio|cp)([^[:alnum:]_-]|$)"
  BARE = "^[0-9]*(>>|>[|]|>&|>|<&|<>|<<<|<|&>>|&>)$"
}
{ all = (NR > 1 ? all RS : "") $0 }
END {
  scan(all, 0, "")
  while (qh < qn) { qh++; scan(QT[qh], QD[qh], QDIR[qh]) }
}
AWK

size=$(printf '%s' "$cmd" | wc -c | tr -d ' ')
if [ "$size" -gt 65536 ]; then
  reason="extract-guard: refused: command too large to check; run it yourself if it is safe: ! <command> (CLAUDE.md § Destructive tools & data loss)"
else
  reason=$(printf '%s' "$cmd" | LC_ALL=C awk "$PROG" 2>/dev/null) || {
    word=$(printf '%s' "$flat" | grep -oE 'dpkg-deb|dpkg|bsdtar|gtar|tar|unzip|cpio|cp' | head -n 1)
    reason="extract-guard: refused: the checker failed on a command that names $word; run it yourself if it is safe: ! <command> (CLAUDE.md § Destructive tools & data loss)"
  }
fi
[ -n "$reason" ] || exit 0
jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
