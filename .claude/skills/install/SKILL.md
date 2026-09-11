---
name: install
description: >
  ติดตั้ง Vibe Coding Guardrails บนเครื่องนี้ — copy hooks, gitleaks config, และ settings
  ให้ครบในขั้นตอนเดียว ใช้เมื่อ: ติดตั้งครั้งแรก หรือ reinstall หลัง update
  Use when: a new team member wants to install the policy, or the user asks to install
  or set up security guardrails.
allowed-tools: Bash(chmod *) Bash(cp *) Bash(mkdir *) Bash(brew *) Bash(apt *) Bash(snap *) Bash(gitleaks *) Bash(ls *) Bash(echo *) Bash(uname *) Bash(command *) Bash(cat *) Bash(python3 *)
---

# Vibe Coding Guardrails — ติดตั้ง

ติดตั้ง Guardrails ให้ครบโดยอัตโนมัติ ไม่ต้องถาม ทำตามขั้นตอนนี้ตามลำดับ
บอกผู้ใช้ว่ากำลังทำอะไรในแต่ละขั้น คุยภาษาไทย

ตั้งตัวแปรก่อน:
```bash
POLICY_DIR="${CLAUDE_SKILL_DIR}/../.."
INSTALL_TARGET="$HOME/.claude"
```

---

## ขั้นตอนที่ 1 — แจ้งแผน

บอกผู้ใช้:

```
กำลังติดตั้ง Vibe Coding Guardrails...

ติดตั้งที่: ~/.claude/ (ทุก project บนเครื่องนี้)
```

---

## ขั้นตอนที่ 2 — Copy Hooks

```bash
mkdir -p ${INSTALL_TARGET}/hooks

cp ${POLICY_DIR}/hooks/session-start-check.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/no-hardcoded-secrets.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/no-sensitive-files-in-git.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/check-public-repo-push.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/check-insecure-patterns.sh ${INSTALL_TARGET}/hooks/

chmod +x ${INSTALL_TARGET}/hooks/*.sh
```

บอก: `✅ Hooks (5 ตัว)`

---

## ขั้นตอนที่ 3 — Copy Gitleaks Config

```bash
cp ${POLICY_DIR}/.gitleaks.toml ${INSTALL_TARGET}/.gitleaks.toml
```

บอก: `✅ Gitleaks config (custom rules: LINE token, Slack webhook, passwords, API keys)`

---

## ขั้นตอนที่ 4 — Merge settings.json

ก่อน merge ต้องรู้ absolute path จริงๆ ก่อน:

```bash
REAL_INSTALL_TARGET=$(echo "$HOME/.claude")
```

ตรวจว่ามี `${REAL_INSTALL_TARGET}/settings.json` อยู่แล้วไหม:

```bash
ls ${REAL_INSTALL_TARGET}/settings.json 2>/dev/null && echo "EXISTS" || echo "NOT_EXISTS"
```

**ถ้าไม่มี:** copy แล้วแทน `${CLAUDE_PROJECT_DIR}` ด้วย absolute path จริงๆ:
```bash
python3 -c "
import json, os
with open('${POLICY_DIR}/settings.json') as f:
    content = f.read()
content = content.replace('\${CLAUDE_PROJECT_DIR}/.claude/hooks', os.path.expanduser('~') + '/.claude/hooks')
with open(os.path.expanduser('~') + '/.claude/settings.json', 'w') as f:
    f.write(content)
print('done')
"
```

**ถ้ามีอยู่แล้ว:** อ่านทั้งสองไฟล์ แล้ว merge เฉพาะ `hooks` และ `permissions.deny` เข้าไป
**สำคัญ:** ทุก path ใน hooks ต้องเป็น absolute path เช่น `/Users/xxx/.claude/hooks/` ห้ามใช้ `$HOME` หรือ `~`
ใช้ `os.path.expanduser('~')` เพื่อ expand path จริง

ทำเลยไม่ต้องถาม แต่บอกว่า merge อะไรไป

บอก: `✅ Settings.json (hooks + permissions)`

---

## ขั้นตอนที่ 5 — ตรวจและติดตั้ง gitleaks

```bash
command -v gitleaks &>/dev/null && echo "INSTALLED" || echo "NOT_INSTALLED"
```

**ถ้ามีแล้ว:**
```bash
gitleaks version
```
บอก: `✅ gitleaks X.X.X`

**ถ้ายังไม่มี:** ตรวจ OS แล้วติดตั้งเลยโดยไม่ถาม:

```bash
uname -s
```

- `Darwin` → `brew install gitleaks`
- `Linux` มี apt → `sudo apt install -y gitleaks`
- `Linux` มี snap → `sudo snap install gitleaks`
- อื่นๆ → บอก URL: https://github.com/gitleaks/gitleaks#installing

บอก: `✅ gitleaks ติดตั้งเสร็จแล้ว` หรือ `❌ ต้องติดตั้ง gitleaks เอง: [URL]`

---

## ขั้นตอนที่ 6 — สรุป

แสดงผล:

```
ติดตั้งเสร็จแล้ว

✅ Hooks (5 ตัว)
✅ Gitleaks config
✅ Settings.json
✅ gitleaks X.X.X

รัน /reload-plugins หรือ restart Claude Code เพื่อให้ hooks เริ่มทำงาน
จากนั้นทดสอบด้วย /vibe-coding-guardrails:test
```

ถ้า gitleaks ไม่ได้ติดตั้ง ให้เปลี่ยนบรรทัด gitleaks เป็น:
```
❌ gitleaks ยังไม่ได้ติดตั้ง — hooks จะบล็อกการแก้ไฟล์จนกว่าจะติดตั้ง
   ติดตั้ง: brew install gitleaks
```
