---
name: install
description: >
  Install Vibe Coding Guardrails on this machine — copies the gitleaks config
  with custom rules and installs gitleaks if needed. Hooks load automatically
  from the plugin when enabled; no manual settings changes required.
  Use when: a new team member wants to install the policy, or the user asks to install
  or set up security guardrails.
allowed-tools: Bash(mkdir *) Bash(cp *) Bash(brew *) Bash(apt *) Bash(snap *) Bash(gitleaks *) Bash(echo *) Bash(uname *) Bash(command *) Bash(ls *)
---

# Vibe Coding Guardrails — ติดตั้ง

ติดตั้ง Guardrails ให้พร้อมใช้งาน คุยภาษาไทย บอกผู้ใช้ว่ากำลังทำอะไรในแต่ละขั้น

ตั้งตัวแปรก่อน:
```bash
POLICY_DIR="${CLAUDE_SKILL_DIR}/../.."
```

---

## ขั้นตอนที่ 1 — แจ้งแผน

บอกผู้ใช้:

```
กำลังติดตั้ง Vibe Coding Guardrails...

Hooks ทำงานอัตโนมัติทันทีที่ plugin เปิดใช้งาน — ไม่ต้องตั้งค่าเพิ่ม
```

---

## ขั้นตอนที่ 2 — Copy Gitleaks Config

Copy `.gitleaks.toml` ไปที่ `~/.claude/` เพื่อให้ hook ใช้ custom rules ได้:

```bash
mkdir -p "$HOME/.claude"
cp "${POLICY_DIR}/.gitleaks.toml" "$HOME/.claude/.gitleaks.toml"
```

บอก: `✅ Gitleaks config (custom rules: LINE token, Slack webhook, passwords, API keys)`

---

## ขั้นตอนที่ 3 — Copy CLAUDE.md (Security Baseline)

Copy `CLAUDE.md` ไปที่ `~/.claude/CLAUDE.md` เพื่อให้ security rules โหลดทุก session บนเครื่องนี้:

```bash
cp "${POLICY_DIR}/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
```

บอก: `✅ CLAUDE.md (security baseline — โหลดทุก session อัตโนมัติ)`

---

## ขั้นตอนที่ 4 — ตรวจและติดตั้ง gitleaks

```bash
command -v gitleaks &>/dev/null && echo "INSTALLED" || echo "NOT_INSTALLED"
```

**ถ้ามีแล้ว:**
```bash
gitleaks version
```
บอก: `✅ gitleaks X.X.X`

**ถ้ายังไม่มี:** ตรวจ OS แล้วติดตั้งเลย:

```bash
uname -s
```

- `Darwin` → `brew install gitleaks`
- `Linux` มี apt → `sudo apt install -y gitleaks`
- `Linux` มี snap → `sudo snap install gitleaks`
- อื่นๆ → บอก: https://github.com/gitleaks/gitleaks#installing

บอก: `✅ gitleaks ติดตั้งเสร็จแล้ว` หรือ `❌ ต้องติดตั้ง gitleaks เอง: [URL]`

---

## ขั้นตอนที่ 5 — สรุป

แสดงผล:

```
ติดตั้งเสร็จแล้ว

✅ Gitleaks config
✅ CLAUDE.md (security baseline)
✅ gitleaks X.X.X

Hooks ที่ทำงานอัตโนมัติ (ไม่ต้องทำอะไรเพิ่ม):
- สแกน secret ทุกครั้งที่แก้ไฟล์ (gitleaks + custom rules)
- บล็อก .env / .pem / .key จาก git commit
- บล็อก push ขึ้น public GitHub repo
- บล็อก CORS wildcard และ localStorage token

รัน /vibe-coding-guardrails:test เพื่อยืนยันว่า hooks ทำงานถูกต้อง
```

ถ้า gitleaks ไม่ได้ติดตั้ง:
```
❌ gitleaks ยังไม่ได้ติดตั้ง — hooks จะบล็อกการแก้ไฟล์จนกว่าจะติดตั้ง
   ติดตั้ง: brew install gitleaks
```
