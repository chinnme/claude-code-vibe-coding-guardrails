# Vibe Coding Guardrail

บริษัทหลายแห่งทำข้อมูลหลุดไปเพราะ Developer เผลอ Commit `API_KEY` หรือไฟล์ที่มีข้อมูลสำคัญขึ้น Public Repository เช่น GitHub — แต่ปัญหาใหญ่กว่าคือตอนนี้ทีมที่ไม่ใช่ Developer ก็ใช้ AI Coding Agent เขียน Code ได้แล้ว และ Agent ที่ไม่มี Guardrail ก็ทำผิดพลาดแบบเดิมได้เหมือนกัน

**Vibe Coding Guardrail** คือชุด Policy เริ่มต้นสำหรับ Claude Code ที่ออกแบบมาให้ Non-Developer สามารถใช้งานได้อย่างปลอดภัย เพราะ Policy ทำหน้าที่ Enforce แทนคนโดยอัตโนมัติ

---

## ติดตั้งก่อนอ่านต่อ

ถ้าอยากข้ามรายละเอียดและเริ่มใช้งานเลย ทำ 3 ขั้นตอนนี้ใน Claude Code:

```
/plugin marketplace add chinnme/claude-code-vibe-coding-guardrail
/plugin install vibe-coding-guardrail@chinnme
/vibe-coding-guardrail:setup
```

ตอน `/plugin install` Claude Code จะถามว่าจะติดตั้ง Scope ไหน — เลือก **"Install for you (user scope)"** เพื่อให้ Policy ทำงานกับทุก Project บนเครื่อง:

| Scope | เก็บที่ | ใครได้ใช้ |
|---|---|---|
| **User** (แนะนำ) | `~/.claude/settings.json` | ทุก Project ของคุณบนเครื่องนี้ |
| **Project** | `.claude/settings.json` (commit ขึ้น git) | ทุกคนที่ clone repo นี้ |
| **Local** | `.claude/settings.local.json` (gitignored) | แค่คุณคนเดียวใน repo นี้ |

`/vibe-coding-guardrail:setup` จะพา User ผ่าน installation ที่เหลือทั้งหมด โดย Claude จะ:

1. ตรวจสอบ hooks, skills, และ settings ที่ bundled มากับ plugin
2. ถามว่าต้องการติดตั้ง global (`~/.claude/`) หรือเฉพาะ project นี้
3. ถามว่าต้องการ copy `CLAUDE.md` ลง project ไหม
4. ตรวจสอบว่า `gitleaks` ติดตั้งอยู่ไหม และเสนอติดตั้งให้ถ้ายังไม่มี
5. แสดง diff ก่อน merge กับ `settings.json` ที่มีอยู่แล้ว

---

## Policy นี้มีอะไรบ้าง

ภาพรวมของไฟล์ทั้งหมด:

```
vibe-coding-guardrail/
├── CLAUDE.md                                  ← กฎที่ Claude อ่านทุก Session
├── settings.json                              ← Wire Hook ทั้งหมด (template)
├── hooks/                                     ← Hook Scripts (source)
│   ├── session-start-check.sh
│   ├── no-hardcoded-secrets.sh
│   ├── no-sensitive-files-in-git.sh
│   ├── confirm-destructive-ops.sh
│   ├── check-public-repo-push.sh
│   ├── check-insecure-patterns.sh
│   └── test-hooks.sh                          ← Unit + Integration Test Suite
├── skills/                                    ← Skill Definitions (source)
│   ├── setup/                                 ← /vibe-coding-guardrail:setup
│   ├── new-project/                           ← /vibe-coding-guardrail:new-project
│   ├── check-secrets/                         ← /vibe-coding-guardrail:check-secrets
│   └── check-before-deploy/                   ← /vibe-coding-guardrail:check-before-deploy
├── .claude-plugin/
│   ├── plugin.json                            ← Plugin identity
│   └── marketplace.json                       ← Marketplace catalog
└── .claude/                                   ← Bundled copy (ติดตั้งผ่าน plugin)
    ├── settings.json
    ├── hooks/
    └── skills/
```

Policy แบ่งเป็นสองส่วนหลัก:
1. **CLAUDE.md** ที่เป็น Advisory (Claude อ่านแล้วพยายามทำตาม)
2. **Hooks** ที่เป็น Enforcement (บังคับจริง ไม่มีทางเลี่ยง)

---

## CLAUDE.md — กฎที่ Claude รู้ว่าต้องทำ

`CLAUDE.md` คือไฟล์ที่ Claude Code โหลดเข้า Context ทุกครั้งที่เปิด Session เหมือนกับ Brief ที่ให้พนักงานใหม่อ่านวันแรก — Claude จะรู้ว่ามีกฎอะไรบ้างและพยายามทำตาม

ใน Template นี้มีกฎสำคัญ 5 กลุ่ม:

1. **Security Rules** — ห้าม Hardcode Secret, ต้องมี `.env` ใน `.gitignore`, ห้าม Push ตรงไป `main`, ห้าม Push ไป Public Repo โดยไม่ยืนยัน

2. **Communication** — ทำงานได้เลย ไม่ต้อง Confirm ทุก Step แต่ถ้าไม่แน่ใจให้ถาม และถ้าจะทำอะไรที่ย้อนกลับไม่ได้ต้องบอกก่อน

3. **Code Rules** — ห้าม Suppress Error ด้วย `@ts-ignore` หรือ `eslint-disable`, ห้าม Log ข้อมูลส่วนตัว, ห้าม Bump Dependency โดยไม่บอก

4. **API and Web Security Rules** — ห้าม CORS Wildcard, บังคับ HTTPS, ห้าม Token ใน `localStorage`, ห้ามเขียน Authentication เอง, ห้าม Admin Credential อยู่ฝั่ง Client

5. **Before Saying Done** — ต้องรัน Test ก่อน, ตรวจว่าไม่มี Secret ใน File ที่แก้, แล้ว Summarize ว่าทำอะไรไปบ้าง

> **ข้อสำคัญ:** CLAUDE.md คือ Advisory ไม่ใช่ Enforcement — Claude อ่านแล้ว *พยายาม* ทำตาม แต่ไม่มี Guarantee 100% Hook เท่านั้นที่ Enforce จริง

---

## Hooks — ตรวจอัตโนมัติ

Hook คือ Script ที่ Claude Code รันโดยอัตโนมัติก่อนหรือหลัง Claude ทำงาน — ไม่ว่า Claude จะ "ตัดสินใจ" อะไร Hook ก็จะยังทำงานของมัน เหมือนกับ Gate ที่ประตูที่ต้องผ่านทุกครั้งโดยไม่มีข้อยกเว้น

เรามีการใช้ Hook 3 ประเภท:

### 1. SessionStart — ทำงานตอนเปิด Claude Code ขึ้นมา

**`session-start-check.sh`** — ตรวจว่า `gitleaks` ติดตั้งอยู่ไหม

- ถ้ามีอยู่แล้ว → Update อัตโนมัติด้วย `brew upgrade gitleaks` แบบ Background ไม่รอ
- ถ้าไม่มี → Claude จะถาม User ว่า "จะให้ Install ให้เลยไหม?" พร้อมรัน Install Command ถ้า User บอก Yes

### 2. PreToolUse — ทำงานตอน Claude รัน Bash Command

**`confirm-destructive-ops.sh`** — Block คำสั่งที่อันตราย เช่น `rm -rf`, `DROP TABLE`, `git push --force`, Deploy ไป Production และ Push ตรงไป `main`/`master`

**`no-sensitive-files-in-git.sh`** — Block `git add` หรือ `git commit` ถ้า File ที่กำลัง Stage เป็นไฟล์ประเภทที่ไม่ควร Commit เช่น `.env`, `.pem`, `.key`, `CLAUDE.local.md`

**`check-public-repo-push.sh`** — ก่อน `git push` ทุกครั้ง Hook จะ Curl ไปเช็คว่า GitHub Repo เป็น Public ไหม (ถ้า Unauthenticated Curl ได้ HTTP 200 = Public) — ถ้าใช่จะ Block พร้อมให้ User Confirm ก่อน

### 3. PostToolUse — ทำงานหลัง Claude เขียนหรือแก้ไฟล์

**`no-hardcoded-secrets.sh`** — หลังแก้ไฟล์ทุกครั้ง Hook จะ Pipe เนื้อหาไฟล์เข้า `gitleaks` — ถ้าเจอ Secret จะ Block ทันที (exit 2) ถ้าไม่มี `gitleaks` ในเครื่องก็ Block เช่นกัน

**`check-insecure-patterns.sh`** — ตรวจ Pattern ที่ไม่ปลอดภัยในโค้ดที่ gitleaks จับไม่ได้ ได้แก่ CORS Wildcard (`origin: "*"`) และการเก็บ Token ใน `localStorage`

---

## Skills — คำสั่งพิเศษที่พิมพ์ตรงๆ ใน Claude Code

นอกจาก Hook ที่ทำงานเองแล้ว ยังมี Skill ที่เรียกใช้ได้ตามต้องการ Claude จะ Invoke Skill เหล่านี้เองด้วยถ้าเห็นว่า Context เหมาะสม — หรือจะพิมพ์ตรงๆ ก็ได้

| พิมพ์ | ใช้เมื่อไหร่ | Claude จะทำอะไร |
|---|---|---|
| `/vibe-coding-guardrail:setup` | ครั้งแรกที่ติดตั้ง | Copy hooks, skills, settings, และ install gitleaks ลงเครื่อง |
| `/vibe-coding-guardrail:new-project` | เริ่ม project ใหม่ทุกครั้ง | สร้าง `.gitignore`, `.env.example`, Init Git ก่อนเขียน Code บรรทัดแรก |
| `/vibe-coding-guardrail:check-secrets` | ก่อน commit | Scan ทุกไฟล์ที่แก้ใน Session นี้ + ตรวจว่า `.gitignore` ครอบคลุมพอไหม |
| `/vibe-coding-guardrail:check-before-deploy` | ก่อน deploy / ก่อน push ขึ้น public | รัน Pre-Deploy Checklist ครบ 4 ด้าน: git tracking, `.gitignore`, insecure patterns, และ gitleaks scan |

### Flow ที่แนะนำ

```
เริ่ม project ใหม่
     ↓
/vibe-coding-guardrail:new-project
     ↓
เขียน code ตามปกติ (hooks ทำงานเองทุก file save)
     ↓
ก่อน commit → /vibe-coding-guardrail:check-secrets  (optional แต่แนะนำ)
     ↓
ก่อน deploy → /vibe-coding-guardrail:check-before-deploy  (บังคับ)
```

Hook ทำงานเองโดยอัตโนมัติตลอดเวลา ไม่ต้องสั่ง Skill ช่วยตรวจในระดับที่กว้างกว่า Hook สามารถตรวจสอบหลายไฟล์พร้อมกัน และให้คำแนะนำ step-by-step ได้

---

## ทดสอบว่า Hook ทำงานถูกต้องไหม

Policy นี้มี Test Suite สองระดับ:

```bash
# รัน Unit + Integration Tests ทั้งหมด
bash .claude/hooks/test-hooks.sh

# รัน เฉพาะ Integration Tests (ใช้ claude -p จริง)
bash .claude/hooks/test-hooks.sh integration

# รัน Test เฉพาะ Hook ที่สนใจ
bash .claude/hooks/test-hooks.sh confirm-destructive-ops
bash .claude/hooks/test-hooks.sh check-public-repo-push
```

### Unit Tests
Pipe JSON Input เข้า Hook Script โดยตรง ตรวจว่า Exit Code ถูกต้อง ใช้ Full JSON Input Format ตาม Official Docs ของ Claude Code ไม่ต้องการ `claude` CLI

### Integration Tests
รัน `claude -p` จริงแล้วตรวจว่า Claude ตอบสนองต่อการ Block ถูกต้อง ครอบคลุมทุก Hook ต้องมี `claude` CLI และ `ANTHROPIC_API_KEY` ในเครื่อง

| Test Type | จำนวน | ต้องการ |
|---|---|---|
| Unit | 56 | Bash 3.2+ |
| Integration | 9 | claude CLI + API Key |
| **รวม** | **67** | |

Tests บาง Suite จะ SKIP ถ้า Linter ไม่ได้ติดตั้ง (ruff, shellcheck) — นับเป็น Expected ไม่ใช่ Failure

---

## ปรับ Policy ให้เหมาะกับ Project ตัวเอง

หลัง Copy `CLAUDE.md` ไปแล้ว เพิ่ม Section เหล่านี้ตามที่มีใน Project:

```markdown
## Commands
- Start: npm start
- Test: npm test

## Environment Variables
Project นี้อ่าน .env สำหรับ:
- DATABASE_URL — Connection String ของ Database
- OPENAI_API_KEY — API Key สำหรับ OpenAI

## Known Claude Mistakes in This Project
- ต้องใส่ CORS Headers ทุก API Response เสมอ
- Database รันบน Port 5433 ไม่ใช่ 5432
```

Section สุดท้าย "Known Claude Mistakes" สำคัญมาก — ทุกครั้งที่ Claude ทำผิดซ้ำให้เพิ่มไว้ที่นี่เลย เพราะ Claude จะอ่านทุก Session และจำไว้

---

## ข้อจำกัดที่ต้องรู้

- **gitleaks บังคับ** — ถ้าไม่มี `gitleaks` ในเครื่อง Claude จะ Block การแก้ไฟล์ทุกไฟล์ ติดตั้งก่อนใช้งาน

- **Hooks ต้องมีสิทธิ์รัน** — ถ้า Hook ไม่ทำงาน ให้รัน `chmod +x .claude/hooks/*.sh`

- **`check-public-repo-push.sh` ต้องการ Internet** — Hook นี้ Curl ไปเช็ค GitHub ถ้า Offline จะข้ามไปและอนุญาตให้ Push (Soft Fail)

- **Windows ยังไม่รองรับ** — Hook ทั้งหมดเขียนเป็น `.sh` ต้องการ Git Bash ถ้าไม่มี Claude Code จะ Fallback ไป PowerShell และ Hook จะไม่รัน

- **CLAUDE.md เป็นแค่ Advisory** — Claude อ่านแล้วพยายามทำตาม แต่ไม่ใช่ Hard Enforcement — Deterministic Enforcement ทำได้แค่ผ่าน Hook เท่านั้น

---

## References

- [Claude Code Hooks Docs](https://code.claude.com/docs/en/hooks)
- [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)
- [gitleaks](https://github.com/gitleaks/gitleaks)