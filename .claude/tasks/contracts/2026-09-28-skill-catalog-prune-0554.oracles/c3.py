import glob,os,re,subprocess
H=os.path.expanduser('~'); SRC='skills-external/gstack'; DST=H+'/.claude/skills/gstack'
txt=''.join(open(f,errors='ignore').read() for f in glob.glob(SRC+'/*/SKILL.md'))
paths=set(re.findall(r'(?:~|\$HOME)/\.claude/skills/gstack/([A-Za-z0-9_./-]+)',txt))
paths={p.rstrip('.') for p in paths}
want=[p for p in sorted(paths) if os.path.exists(os.path.join(SRC,p)) and not p.endswith('SKILL.md') and not p.startswith('.git') and not p.startswith('.feature-prompted')]
assert len(want)>=20, want
missing=[p for p in want if not os.path.exists(os.path.join(DST,p))]
assert not missing, missing
for p in ('make-pdf/dist/pdf','lib/diagram-render/dist/diagram-render.html','freeze/bin/check-freeze.sh','scripts/jargon-list.json','ETHOS.md'):
    assert os.path.exists(os.path.join(DST,p)), p
out=subprocess.run(['find','-L',DST,'-name','SKILL.md'],capture_output=True,text=True).stdout.strip()
assert out=='', out
print('LINKS_OK')
