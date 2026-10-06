import json,os,hashlib,glob
H=os.path.expanduser('~')
e=json.load(open('plugins.lock.json'))['superpowers']
cache=glob.glob(H+'/.claude/plugins/cache/superpowers-marketplace/superpowers/6.4.1/skills')
missing=[];mism=[]
for k,files in e['skills'].items():
    for f in files:
        p=f'skills-external/{k}/{f}'
        if not os.path.isfile(p): missing.append(p); continue
        if cache:
            c=f'{cache[0]}/{k}/{f}'
            if os.path.isfile(c) and hashlib.md5(open(p,'rb').read()).hexdigest()!=hashlib.md5(open(c,'rb').read()).hexdigest(): mism.append(p)
    link=f'{H}/.claude/skills/{k}'
    if not (os.path.islink(link) and os.path.isfile(link+'/SKILL.md')): missing.append(link)
assert not missing, missing
assert not mism, ('byte mismatch vs plugin cache',mism)
print('VENDORED_LINKED')
