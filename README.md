# Vibe Coding Guardrails

บริษัทหลายแห่งทำข้อมูลหลุดไปเพราะ Developer เผลอ Commit `API_KEY` หรือไฟล์ที่มีข้อมูลสำคัญขึ้น Public Repository เช่น GitHub — แต่ปัญหาใหญ่กว่าคือตอนนี้ทีมที่ไม่ใช่ Developer ก็ใช้ AI Coding Agent เขียน Code ได้แล้ว และ Agent ที่ไม่มี Guardrail ก็ทำผิดพลาดแบบเดิมได้เหมือนกัน

**Vibe Coding Guardrails** คือชุด Policy เริ่มต้นสำหรับ Claude Code ที่ออกแบบมาให้ Non-Developer สามารถใช้งานได้อย่างปลอดภัย เพราะ Policy ทำหน้าที่ Enforce แทนคนโดยอัตโนมัติ

---

## ติดตั้งก่อนอ่านต่อ

ถ้าอยากข้ามรายละเอียดและเริ่มใช้งานเลย ทำ 3 ขั้นตอนนี้ใน Claude Code:

```
/plugin marketplace add chinnme/claude-code-vibe-coding-guardrails
/plugin install vibe-coding-guardrails@chinnme
/reload-plugins
/vibe-coding-guardrails:install
```

**ขั้นตอนที่ 1–2** เพิ่ม marketplace และติดตั้ง plugin

**ขั้นตอนที่ 3** `/reload-plugins` — สำคัญ: ต้อง reload ก่อนเพื่อให้ hooks จาก plugin โหลดเข้า Claude Code (ควรเห็น **5 hooks** หลัง reload)

**ขั้นตอนที่ 4** รัน `/vibe-coding-guardrails:install` — Claude จะ copy `.gitleaks.toml` custom rules และตรวจสอบ gitleaks ให้:

1. **Copy gitleaks config** — custom rules สำหรับ LINE token, Slack webhook, passwords, API keys
2. **ตรวจและติดตั้ง gitleaks** ถ้ายังไม่มีในเครื่อง

หลังติดตั้งเสร็จ รัน `/reload-plugins` หรือ restart Claude Code เพื่อให้ hooks เริ่มทำงาน

---

## Policy นี้มีอะไรบ้าง

ภาพรวมของไฟล์ทั้งหมด:

```
vibe-coding-guardrails/
├── CLAUDE.md                                  ← กฎที่ Claude อ่านทุก Session
├── settings.json                              ← Wire Hook ทั้งหมด (template)
├── hooks/                                     ← Hook Scripts + Config
│   ├── session-start-check.sh
│   ├── no-hardcoded-secrets.sh
│   ├── no-sensitive-files-in-git.sh
│   ├── check-public-repo-push.sh
│   ├── check-insecure-patterns.sh
│   ├── test-hooks.sh                          ← Automated Test Suite
│   └── hooks.json                             ← Plugin hooks (โหลดอัตโนมัติ)
├── skills/                                    ← Skill Definitions
│   ├── install/                               ← /vibe-coding-guardrails:install
│   ├── uninstall/                             ← /vibe-coding-guardrails:uninstall
│   └── test/                                  ← /vibe-coding-guardrails:test
├── .gitleaks.toml                             ← Custom gitleaks rules
├── .claude-plugin/
│   ├── plugin.json                            ← Plugin identity
│   └── marketplace.json                       ← Marketplace catalog
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

**`no-sensitive-files-in-git.sh`** — Block `git add` หรือ `git commit` ถ้า File ที่กำลัง Stage เป็นไฟล์ประเภทที่ไม่ควร Commit เช่น `.env`, `.pem`, `.key`, `CLAUDE.local.md`

**`check-public-repo-push.sh`** — ก่อน `git push` หรือ `gh` command ทุกครั้ง Hook จะ Curl ไปเช็คว่า GitHub Repo เป็น Public ไหม (ถ้า Unauthenticated Curl ได้ HTTP 200 = Public) — ถ้าใช่จะ Block พร้อมแจ้งเหตุผล

### 3. PostToolUse — ทำงานหลัง Claude เขียนหรือแก้ไฟล์

**`no-hardcoded-secrets.sh`** — หลังแก้ไฟล์ทุกครั้ง Hook จะ Pipe เนื้อหาไฟล์เข้า `gitleaks` — ถ้าเจอ Secret จะ Block ทันที (exit 2) ถ้าไม่มี `gitleaks` ในเครื่องก็ Block เช่นกัน

**`check-insecure-patterns.sh`** — ตรวจ Pattern ที่ไม่ปลอดภัยในโค้ดที่ gitleaks จับไม่ได้ ได้แก่ CORS Wildcard (`origin: "*"`) และการเก็บ Token ใน `localStorage`

---

## Skills — คำสั่งพิเศษที่พิมพ์ตรงๆ ใน Claude Code

นอกจาก Hook ที่ทำงานเองแล้ว ยังมี Skill ที่เรียกใช้ได้ตามต้องการ

| พิมพ์ | ใช้เมื่อไหร่ | Claude จะทำอะไร |
|---|---|---|
| `/vibe-coding-guardrails:install` | ครั้งแรกที่ติดตั้ง | ติดตั้ง gitleaks config และ gitleaks ให้พร้อมใช้ |
| `/vibe-coding-guardrails:uninstall` | ต้องการถอนออก | ลบ gitleaks config และ hooks entries ออกจาก settings.json |
| `/vibe-coding-guardrails:test` | หลังติดตั้งหรือต้องการยืนยัน | รัน live test ทุก hook — สร้าง test environment ชั่วคราว, ทดสอบ, ลบทิ้ง, รายงานผล |

---

## ทดสอบว่า Hook ทำงานถูกต้องไหม

### Live Test (แนะนำ)

```
/vibe-coding-guardrails:test
```

Claude จะสร้าง test environment ชั่วคราว ทดสอบแต่ละ hook โดยทำสิ่งที่ policy ห้ามจริงๆ เพื่อพิสูจน์ว่า hook บล็อกได้ แล้วลบทุกอย่างทิ้งและรายงานผล ✅/❌

### Automated Unit Tests

```bash
bash .claude/hooks/test-hooks.sh
```

ผลที่คาดหวัง: `PASS: 29 · FAIL: 0-4 · SKIP: 8`

FAIL ที่ยอมรับได้ (environment issues ไม่ใช่ bug จริง):
- `startup: expected gitleaks mention` — gitleaks ไม่อยู่ใน PATH ของ test shell
- `edge: push no remote` — test folder อาจมี remote ติดมา
- `live: HTTPS/SSH public repo` — network/git context ของ test runner

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
