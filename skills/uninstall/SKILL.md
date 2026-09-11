---
name: uninstall
description: >
  Remove Vibe Coding Guardrails from this machine — deletes gitleaks config,
  CLAUDE.md security baseline, and any hooks entries from settings.json.
  Use when: the user wants to remove the guardrails, uninstall the plugin, or clean up.
allowed-tools: Bash(rm *) Bash(ls *) Bash(echo *) Bash(python3 *) Bash(cat *)
---

# Vibe Coding Guardrails — ถอนออก

ลบทุกอย่างที่ติดตั้งโดย plugin นี้ออกให้สะอาด คุยภาษาไทย

---

## ขั้นตอนที่ 1 — ตรวจสอบก่อน

ตรวจดูว่ามีอะไรที่ต้องลบบ้าง:

```bash
echo "=== gitleaks config ===" && ls ~/.claude/.gitleaks.toml 2>/dev/null && echo "มี" || echo "ไม่มี"
echo "=== hooks ใน settings.json ===" && python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.claude/settings.json')) as f:
        d = json.load(f)
    hooks = d.get('hooks', {})
    print('มี hooks:', list(hooks.keys()) if hooks else 'ไม่มี')
    print('มี permissions:', 'มี' if d.get('permissions') else 'ไม่มี')
except: print('ไม่มี settings.json')
"
```

บอกผู้ใช้ว่าพบอะไรบ้าง แล้วดำเนินการต่อเลย

---

## ขั้นตอนที่ 2 — ลบไฟล์ที่ติดตั้งทั้งหมด

ลบทุกอย่างพร้อมกันเลย:

```bash
rm -f ~/.claude/.gitleaks.toml && echo "✅ ลบ gitleaks config แล้ว" || echo "(ไม่มี .gitleaks.toml)"
rm -f ~/.claude/CLAUDE.md && echo "✅ ลบ CLAUDE.md แล้ว" || echo "(ไม่มี CLAUDE.md)"
```

บอกผลของแต่ละ command

---

## ขั้นตอนที่ 3 — ลบ Hooks และ Permissions ออกจาก settings.json

```bash
python3 -c "
import json, os

settings_path = os.path.expanduser('~/.claude/settings.json')
if not os.path.exists(settings_path):
    print('ไม่มี settings.json — ข้าม')
    exit(0)

with open(settings_path) as f:
    d = json.load(f)

changed = []

if 'hooks' in d:
    del d['hooks']
    changed.append('hooks')

if 'permissions' in d:
    deny = d['permissions'].get('deny', [])
    guardrails_deny = [
        'Read(./.env)', 'Read(./.env.*)', 'Read(**/*.pem)',
        'Read(**/*.key)', 'Read(**/id_rsa*)', 'Read(~/.ssh/**)',
        'Read(~/.aws/credentials)'
    ]
    new_deny = [r for r in deny if r not in guardrails_deny]
    if len(new_deny) != len(deny):
        changed.append('permissions.deny')
    if new_deny:
        d['permissions']['deny'] = new_deny
    else:
        del d['permissions']

with open(settings_path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')

if changed:
    print('ลบออกแล้ว:', ', '.join(changed))
else:
    print('ไม่พบ guardrails settings — ข้าม')
"
```

บอก: `✅ ลบ hooks และ permissions ออกจาก settings.json แล้ว`

---

## ขั้นตอนที่ 4 — แนะนำ Uninstall Plugin

บอกผู้ใช้:

```
สิ่งที่ลบออกแล้ว:
✅ Gitleaks config (~/.claude/.gitleaks.toml)
✅ CLAUDE.md security baseline (~/.claude/CLAUDE.md)
✅ Hooks และ permissions ออกจาก settings.json

ขั้นตอนสุดท้าย — รัน command นี้เพื่อ uninstall plugin:
/plugin uninstall vibe-coding-guardrails@chinnme

แล้วรัน /reload-plugins เพื่อให้มีผล
```

---

## ขั้นตอนที่ 5 — ยืนยัน

หลังจากที่ผู้ใช้รัน uninstall command แล้ว ให้ตรวจสอบอีกรอบ:

```bash
python3 -c "
import json, os
settings_path = os.path.expanduser('~/.claude/settings.json')
with open(settings_path) as f:
    d = json.load(f)
print('hooks:', 'มี' if d.get('hooks') else 'ไม่มี')
print('permissions:', 'มี' if d.get('permissions') else 'ไม่มี')
print('gitleaks.toml:', 'มี' if os.path.exists(os.path.expanduser('~/.claude/.gitleaks.toml')) else 'ไม่มี')
print('CLAUDE.md:', 'มี' if os.path.exists(os.path.expanduser('~/.claude/CLAUDE.md')) else 'ไม่มี')
"
```

ถ้าสะอาดหมดแล้ว บอก: `✅ ถอน Vibe Coding Guardrails ออกเรียบร้อยแล้ว`
