---
name: setup
description: >
  ติดตั้ง Vibe Coding Guardrails บนเครื่องนี้ — copy hooks, settings, และ gitleaks config
  ให้ครบ พร้อมใช้งานทันที ใช้เมื่อ: ติดตั้งครั้งแรก หรือ reinstall หลัง upgrade
  Use when: a new team member wants to set up the policy, or the user asks to install or
  set up security guardrails.
allowed-tools: Bash(chmod *) Bash(cp *) Bash(mkdir *) Bash(brew *) Bash(apt *) Bash(gitleaks *) Bash(ls *) Bash(echo *) Bash(uname *) Bash(command *) Bash(cat *)
---

# Vibe Coding Guardrails — ติดตั้ง

ช่วยผู้ใช้ติดตั้ง Vibe Coding Guardrails บนเครื่อง
ทำงานทีละขั้นตอน คุยภาษาไทย อธิบายสั้นๆ ว่าทำอะไรในแต่ละขั้น

ไฟล์ policy อยู่ใน plugin bundle — ใช้ `${CLAUDE_SKILL_DIR}/../..` เพื่อ reference

ตั้งตัวแปรนี้ก่อน:
```bash
POLICY_DIR="${CLAUDE_SKILL_DIR}/../.."
```

---

## ขั้นตอนที่ 1 — ถามว่าจะติดตั้งที่ไหน

บอกผู้ใช้ว่า:

> "ติดตั้ง Guardrails ที่ไหนดีครับ?
>
> **[Enter] ทุก Project (แนะนำ)** — ติดตั้งที่ `~/.claude/` ครอบคลุมทุก project บนเครื่องนี้
> **2** เฉพาะ project นี้ — ติดตั้งที่ `.claude/` ใน folder ปัจจุบัน
>
> กด Enter เพื่อเลือก 'ทุก Project' หรือพิมพ์ 2"

ตั้ง `INSTALL_TARGET` ตามคำตอบ:
- กด Enter หรือพิมพ์ 1 → `INSTALL_TARGET="$HOME/.claude"`
- พิมพ์ 2 → `INSTALL_TARGET=".claude"`

---

## ขั้นตอนที่ 2 — ติดตั้ง Hooks

บอกว่า: "กำลัง copy hooks..."

```bash
mkdir -p ${INSTALL_TARGET}/hooks

cp ${POLICY_DIR}/hooks/session-start-check.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/no-hardcoded-secrets.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/no-sensitive-files-in-git.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/check-public-repo-push.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/check-insecure-patterns.sh ${INSTALL_TARGET}/hooks/

chmod +x ${INSTALL_TARGET}/hooks/*.sh
```

บอก hooks ที่ copy ไป 5 ตัว

---

## ขั้นตอนที่ 3 — ติดตั้ง Gitleaks Config

บอกว่า: "กำลัง copy gitleaks config..."

copy `.gitleaks.toml` จาก plugin ไป `~/.claude/`:

```bash
cp ${POLICY_DIR}/.gitleaks.toml $HOME/.claude/.gitleaks.toml
```

บอกว่า: "ติดตั้ง custom rules สำหรับ LINE token, Slack webhook, passwords, และ API keys เรียบร้อย"

---

## ขั้นตอนที่ 4 — Merge settings.json

ตรวจว่ามี `${INSTALL_TARGET}/settings.json` อยู่แล้วไหม:

```bash
ls ${INSTALL_TARGET}/settings.json 2>/dev/null && echo "EXISTS" || echo "NOT_EXISTS"
```

**ถ้าไม่มี:** copy ตรงๆ:
```bash
cp ${POLICY_DIR}/settings.json ${INSTALL_TARGET}/settings.json
```

**ถ้ามีอยู่แล้ว:** บอกผู้ใช้ว่า:
> "มี settings.json อยู่แล้ว — จะแสดงสิ่งที่ต้องเพิ่ม (hooks และ permissions) ให้ confirm ก่อนเขียน"

อ่านทั้งสองไฟล์ merge เฉพาะ `hooks` และ `permissions.deny` แล้วถามก่อนเขียน

---

## ขั้นตอนที่ 5 — ติดตั้ง gitleaks

ตรวจว่ามี gitleaks อยู่แล้วไหม:

```bash
command -v gitleaks &>/dev/null && echo "INSTALLED: $(gitleaks version)" || echo "NOT_INSTALLED"
```

**ถ้ามีแล้ว:** บอกว่า "gitleaks พร้อมใช้งานแล้ว" แล้วข้ามไปขั้นตอนที่ 6

**ถ้ายังไม่มี:** ตรวจ OS แล้วถาม:

```bash
uname -s
```

- `Darwin` (macOS): ถามว่า "ให้ติดตั้ง gitleaks ผ่าน Homebrew เลยไหม? ([Enter] ใช่ / พิมพ์ n ข้าม)"
  - ถ้ายืนยัน → `brew install gitleaks`
- `Linux`:
  - มี apt → `sudo apt install -y gitleaks`
  - มี snap → `sudo snap install gitleaks`
  - อื่นๆ → แสดง: https://github.com/gitleaks/gitleaks#installing

---

## ขั้นตอนที่ 6 — ตรวจสอบ

```bash
echo "=== Hooks ===" && ls ${INSTALL_TARGET}/hooks/*.sh
echo "=== Gitleaks config ===" && (ls $HOME/.claude/.gitleaks.toml 2>/dev/null && echo "present" || echo "missing")
echo "=== gitleaks ===" && (command -v gitleaks &>/dev/null && gitleaks version || echo "NOT INSTALLED")
echo "=== settings.json ===" && (ls ${INSTALL_TARGET}/settings.json 2>/dev/null && echo "present" || echo "missing")
```

---

## ขั้นตอนที่ 7 — สรุป

แสดงผลสรุป:

```
✅ ติดตั้ง Vibe Coding Guardrails เรียบร้อยแล้ว!

ติดตั้งที่: ${INSTALL_TARGET}

Hooks ที่ทำงานอัตโนมัติ (ไม่ต้องทำอะไรเพิ่ม):
- สแกน secret ทุกครั้งที่แก้ไฟล์ (gitleaks + custom rules)
- บล็อก .env / .pem / .key จาก git commit
- บล็อก push ขึ้น public GitHub repo
- บล็อก CORS wildcard และ localStorage token

ขั้นตอนต่อไป:
1. รัน /reload-plugins หรือ restart Claude Code เพื่อให้ hooks เริ่มทำงาน
2. รัน /vibe-coding-guardrails:test เพื่อยืนยันว่า hooks ทำงานถูกต้อง
```

ถ้า gitleaks ยังไม่ได้ติดตั้ง ให้เพิ่ม:
```
⚠️  gitleaks ยังไม่ได้ติดตั้ง — Claude จะบล็อกการแก้ไฟล์จนกว่าจะติดตั้ง
   ติดตั้ง: brew install gitleaks  (macOS)
            sudo apt install gitleaks  (Linux)
```
