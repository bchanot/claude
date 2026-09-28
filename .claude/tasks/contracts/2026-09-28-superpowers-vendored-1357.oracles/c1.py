import json,re
d=json.load(open('plugins.lock.json'))
e=d['superpowers']
assert e['source']=='https://github.com/obra/superpowers', e['source']
assert e['commit']=='5bf4e78011075bcfc0dc295f0724994cd123ee71', e['commit']
assert e['path']=='skills', e.get('path')
assert e.get('managed_by')=='curl'
want={'brainstorming','writing-plans','subagent-driven-development','test-driven-development','requesting-code-review','using-git-worktrees','writing-skills'}
assert set(e['skills'])==want, set(e['skills'])^want
for k,files in e['skills'].items():
    assert 'SKILL.md' in files, k
    for f in files: assert re.fullmatch(r'[A-Za-z0-9._/-]+',f) and '..' not in f, f
assert 'scripts/sdd-workspace' in e['skills']['subagent-driven-development']
assert 'code-reviewer.md' in e['skills']['requesting-code-review']
assert 'anthropic-best-practices.md' in e['skills']['writing-skills']
print('LOCK_OK')
