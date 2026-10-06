import glob,re,sys
def entries(p): return {l.split()[0] for l in open(p) if l.strip() and not l.lstrip().startswith('#')}
sup=[p for p in glob.glob('lib/profiles/*.profile') if re.search(r'^# SUPERSET-OF: full\s*$',open(p).read(),re.M)]
assert len(sup)==1, sup
full=entries('lib/profiles/full.profile'); S=entries(sup[0])
parked={'make-pdf','diagram','21st-ai','21st-ui-explore','21st-ui-review'}
assert not (parked & full), parked & full
assert full <= S, full - S
assert parked <= S, parked - S
removed={'ship','land-and-deploy','setup-deploy','autoplan','context-save','learn','careful','guard','design-shotgun'}
U=set()
for p in glob.glob('lib/profiles/*.profile'): U|=entries(p)
assert not (removed & U), removed & U
assert (U-removed) <= S, (U-removed)-S
print('SUPERSET_OK')
