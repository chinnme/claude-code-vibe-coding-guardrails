---
name: test
description: >
  ทดสอบว่า Vibe Coding Guardrails hooks ทำงานถูกต้องไหม — สร้าง test environment ชั่วคราว
  ทดสอบแต่ละ hook โดยทำสิ่งที่ policy ห้ามจริงๆ แล้วลบทิ้ง รายงานผล ✅/❌
  Use when: after setup, after update, or to verify hooks are working correctly.
allowed-tools: Bash(*) Write(*) Edit(*) Read(*)
---

# Vibe Coding Guardrails — ทดสอบ Hooks

ทดสอบ hooks ทั้งหมดแบบ live — สร้าง test environment ชั่วคราว ทำสิ่งที่ policy ห้ามจริงๆ
เพื่อพิสูจน์ว่า hooks บล็อกได้ แล้วลบทิ้งและรายงานผล

**สำคัญ:**
- การทดสอบนี้จะทำสิ่งที่ผิดกฎ policy โดยตั้งใจ เพื่อพิสูจน์ว่า hooks ทำงาน
- เมื่อ hook บล็อก = ✅ PASS (hook ทำงานถูกต้อง) บันทึกผลแล้วทำ test ถัดไปต่อเลย
- **ห้าม fork หรือ spawn subagent** — ทำทุก test ใน session นี้เท่านั้น ถ้า hook บล็อกการเขียนไฟล์ ให้บันทึก PASS แล้วไปต่อได้เลย ไม่ต้องลองใหม่

บอกผู้ใช้ก่อนเริ่ม:
> "กำลังรัน live test — จะทำสิ่งที่ policy ห้ามเพื่อพิสูจน์ว่า hooks ทำงานได้ แต่ละ test คาดว่าจะถูกบล็อก ✅ = hook ทำงานถูกต้อง"

---

## เตรียม Test Environment

```bash
PROJECT_DIR="$(pwd)"
TEST_DIR="${PROJECT_DIR}/.guardrails-test-tmp"
REPORT_FILE="${PROJECT_DIR}/guardrails-test-report.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "${TEST_DIR}"
cd "${TEST_DIR}"
git init -q
git config user.email "test@example.com"
git config user.name "Guardrails Test"
touch .gitignore
git add .gitignore
git commit -q -m "init"
git remote add origin https://github.com/anthropics/anthropic-sdk-python.git
cd "${PROJECT_DIR}"
```

บอกว่า: "สร้าง test environment ที่ `.guardrails-test-tmp/` เรียบร้อย"

---

## Section 1: ตรวจสอบการติดตั้ง

รัน checks เหล่านี้และบันทึกผล:

### 1.1 Plugin เปิดใช้งานอยู่
```bash
grep -q "vibe-coding-guardrails" ~/.claude/settings.json 2>/dev/null && echo "PASS" || echo "FAIL"
```

### 1.2 Hooks ครบ 5 ตัว
```bash
EXPECTED="session-start-check.sh no-hardcoded-secrets.sh no-sensitive-files-in-git.sh check-public-repo-push.sh check-insecure-patterns.sh"
FOUND=0
for h in $EXPECTED; do
  [ -x "$HOME/.claude/hooks/$h" ] && FOUND=$((FOUND + 1))
done
[ "$FOUND" -eq 5 ] && echo "PASS (5/5)" || echo "FAIL ($FOUND/5)"
```

### 1.3 Gitleaks config ติดตั้งแล้ว
```bash
[ -f "$HOME/.claude/.gitleaks.toml" ] && echo "PASS" || echo "FAIL (รัน install ก่อน)"
```

### 1.4 gitleaks ติดตั้งแล้ว
```bash
command -v gitleaks &>/dev/null && echo "PASS ($(gitleaks version 2>/dev/null))" || echo "FAIL"
```

### 1.5 CLAUDE.md มีอยู่
```bash
[ -f "CLAUDE.md" ] && echo "PASS" || echo "WARN (ไม่มี CLAUDE.md ใน project นี้)"
```

---

## Section 2: Happy Path — ไม่ควรถูกบล็อก

### 2.1 เขียนไฟล์ที่ปลอดภัย

เขียน content นี้ลงไฟล์ `${TEST_DIR}/clean-file.js`:
```javascript
const apiKey = process.env.API_KEY;
const dbUrl = process.env.DATABASE_URL;

async function fetchData() {
  const res = await fetch('https://api.example.com/data', {
    headers: { Authorization: `Bearer ${apiKey}` }
  });
  return res.json();
}

module.exports = { fetchData };
```

ถ้าเขียนสำเร็จโดยไม่ถูกบล็อก → PASS
ลบไฟล์หลังทดสอบ

### 2.2 Push ไป private repo

```bash
git -C "${TEST_DIR}" remote add test-private https://github.com/chinnme/private-repo-notexist.git 2>/dev/null || true
git -C "${TEST_DIR}" push test-private main --dry-run 2>&1 || true
git -C "${TEST_DIR}" remote remove test-private 2>/dev/null || true
```

Hook ตรวจ HTTP → 404 = ไม่ public → อนุญาต (git error เพราะ repo ไม่มีจริง = คาดหวัง)
ถ้า hook ไม่บล็อก (ไม่มี "BLOCKED") → PASS

---

## Section 3: Security Block Tests — ต้องถูกบล็อก

**เมื่อ hook บล็อก = ✅ PASS**

### 3.1 Hardcoded API key → ต้องบล็อก

เขียน content นี้ลงไฟล์ `${TEST_DIR}/bad-apikey.js`:
```javascript
const openaiKey = "sk-proj-ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef1234567890";
```

Hook `no-hardcoded-secrets.sh` ต้องบล็อก เพราะ custom rules จับ `sk-proj-*`
BLOCKED = PASS | ไม่บล็อก = FAIL
ลบไฟล์หลังทดสอบ

### 3.2 Hardcoded password → ต้องบล็อก

เขียน content นี้ลงไฟล์ `${TEST_DIR}/bad-password.js`:
```javascript
const dbConfig = {
  host: "db.example.com",
  password: "SuperSecret123!",
};
```

Hook `no-hardcoded-secrets.sh` ต้องบล็อก เพราะ custom rules จับ `password: "..."`
BLOCKED = PASS | ไม่บล็อก = FAIL
ลบไฟล์หลังทดสอบ

### 3.3 CORS wildcard → ต้องบล็อก

เขียน content นี้ลงไฟล์ `${TEST_DIR}/bad-cors.js`:
```javascript
const express = require('express');
const cors = require('cors');
const app = express();
app.use(cors({ origin: "*" }));
app.listen(3000);
```

Hook `check-insecure-patterns.sh` ต้องบล็อก
BLOCKED = PASS | ไม่บล็อก = FAIL
ลบไฟล์หลังทดสอบ

### 3.4 localStorage token → ต้องบล็อก

เขียน content นี้ลงไฟล์ `${TEST_DIR}/bad-storage.js`:
```javascript
function saveToken(token) {
  localStorage.setItem('token', token);
}
```

Hook `check-insecure-patterns.sh` ต้องบล็อก
BLOCKED = PASS | ไม่บล็อก = FAIL
ลบไฟล์หลังทดสอบ

### 3.5 git add .env → ต้องบล็อก

```bash
echo "LINE_TOKEN=supersecret123" > "${TEST_DIR}/.env"
git -C "${TEST_DIR}" add .env
```

Hook `no-sensitive-files-in-git.sh` ต้องบล็อก
BLOCKED = PASS | ไม่บล็อก = FAIL

### 3.6 git add .env.local → ต้องบล็อก

```bash
echo "NEXT_PUBLIC_SECRET=abc" > "${TEST_DIR}/.env.local"
git -C "${TEST_DIR}" add .env.local
```

Hook `no-sensitive-files-in-git.sh` ต้องบล็อก
BLOCKED = PASS | ไม่บล็อก = FAIL

### 3.7 git add .pem file → ต้องบล็อก

```bash
echo "-----BEGIN CERTIFICATE-----" > "${TEST_DIR}/server.pem"
git -C "${TEST_DIR}" add server.pem
```

Hook `no-sensitive-files-in-git.sh` ต้องบล็อก
BLOCKED = PASS | ไม่บล็อก = FAIL

### 3.8 Push ไป public repo → ต้องบล็อก

```bash
git -C "${TEST_DIR}" push origin main --dry-run 2>&1 || true
```

Remote ชี้ไป `anthropics/anthropic-sdk-python` ซึ่งเป็น public repo
Hook `check-public-repo-push.sh` ตรวจ HTTP 200 → บล็อก
BLOCKED = PASS | ไม่บล็อก = FAIL

---

## Section 4: Cleanup

```bash
rm -rf "${TEST_DIR}"
```

บอกว่า: "ลบ test environment เรียบร้อย"

---

## Section 5: สร้าง Report

บันทึก `${REPORT_FILE}` โดยใช้ format นี้:

```markdown
# Vibe Coding Guardrails — Test Report

**Project:** [project path]
**วันที่:** [timestamp]
**ทดสอบโดย:** Claude Code

---

## 1. การติดตั้ง

| # | รายการ | ผล |
|---|--------|-----|
| 1.1 | Plugin เปิดใช้งาน | [ผล] |
| 1.2 | Hooks ครบ 5 ตัว | [ผล] |
| 1.3 | Gitleaks config | [ผล] |
| 1.4 | gitleaks ติดตั้งแล้ว | [ผล] |
| 1.5 | CLAUDE.md | [ผล] |

## 2. Happy Path (ไม่ควรถูกบล็อก)

| # | รายการ | คาดหวัง | ผล |
|---|--------|---------|-----|
| 2.1 | เขียนไฟล์ปลอดภัย | ไม่บล็อก | [ผล] |
| 2.2 | Push ไป private repo | ไม่บล็อก | [ผล] |

## 3. Security Block Tests (ต้องถูกบล็อก)

| # | รายการ | Hook | คาดหวัง | ผล |
|---|--------|------|---------|-----|
| 3.1 | Hardcoded API key | no-hardcoded-secrets.sh | บล็อก | [ผล] |
| 3.2 | Hardcoded password | no-hardcoded-secrets.sh | บล็อก | [ผล] |
| 3.3 | CORS wildcard | check-insecure-patterns.sh | บล็อก | [ผล] |
| 3.4 | localStorage token | check-insecure-patterns.sh | บล็อก | [ผล] |
| 3.5 | git add .env | no-sensitive-files-in-git.sh | บล็อก | [ผล] |
| 3.6 | git add .env.local | no-sensitive-files-in-git.sh | บล็อก | [ผล] |
| 3.7 | git add .pem | no-sensitive-files-in-git.sh | บล็อก | [ผล] |
| 3.8 | Push public repo | check-public-repo-push.sh | บล็อก | [ผล] |

---

## สรุป

**รวม:** 15 | **ผ่าน:** X | **ไม่ผ่าน:** X | **ข้าม:** X

[ถ้าผ่านหมด]
### ✅ ทุก Hook ทำงานถูกต้อง

[ถ้าไม่ผ่าน]
### ❌ รายการที่ไม่ผ่าน:
- [รายการ]
```

---

## Section 6: แสดงผลสรุป

```
════════════════════════════════════════════════════════════
  Vibe Coding Guardrails — ผลการทดสอบ
════════════════════════════════════════════════════════════

  รวม: 15 | ✅ ผ่าน: X | ❌ ไม่ผ่าน: X | ⚠️ ข้าม: X

  บันทึก report ที่: guardrails-test-report.md

════════════════════════════════════════════════════════════
```

ถ้ามีรายการไม่ผ่าน ให้อธิบายสาเหตุและวิธีแก้ไข
