import glob,re,subprocess,os
H=os.path.expanduser('~')
files=glob.glob(H+'/.claude/skills/*/SKILL.md')
def desc(p):
    t=open(p,encoding='utf-8',errors='ignore').read(); m=re.match(r'^---\n(.*?)\n---',t,re.S)
    if not m: return 0
    d=re.search(r'^description:\s*(\|[-+]?|>[-+]?)?\s*(.*?)(?=^\S|\Z)',m.group(1),re.S|re.M)
    return len(d.group(2).strip()) if d else 0
exp_chars=sum(desc(p) for p in files); exp_n=len(files)
out=subprocess.run(['bash','doctor.sh'],capture_output=True,text=True).stdout
m=re.search(r'Skill descriptions:\s+~(\d+)t\s+\((\d+) skills\)',out); assert m, 'no skill line'
tok,n=int(m.group(1)),int(m.group(2))
assert n==exp_n,(n,exp_n)
assert abs(tok*4-exp_chars)<=exp_chars*0.05,(tok*4,exp_chars)
print('DOCTOR_COUNTS')
