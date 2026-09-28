import glob,os,re
def entries(p): return {l.split()[0] for l in open(p) if l.strip() and not l.lstrip().startswith('#')}
full=entries('lib/profiles/full.profile')
removed={'ship','land-and-deploy','setup-deploy','autoplan','context-save','learn','careful','guard','design-shotgun'}
trio={'21st-ai','21st-ui-explore','21st-ui-review'}
test=open('lib/tests/profile-census.test.sh').read()
m=re.search(r'^\s*FULL_EXCEPTIONS=\(([^)]*)\)',test,re.M)
allow=set(m.group(1).split()) if m else set()
gap=set()
for p in glob.glob('lib/profiles/*.profile'):
    if os.path.basename(p) in ('full.profile','max.profile'): continue
    gap|=entries(p)-full
gap-=removed|trio|allow
assert not gap, sorted(gap)
assert 'pr-review-toolkit' in allow, 'allowlist must name pr-review-toolkit'
print('FULL_UNION_OK')
