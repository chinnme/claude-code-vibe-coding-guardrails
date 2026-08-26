# Vibe Coding Policy

บริษัทหลายแห่งทำข้อมูลหลุดไปเพราะ Developer เผลอ Commit `API_KEY` หรือไฟล์ที่มีข้อมูลสำคัญขึ้น Public Repository เช่น GitHub — แต่ปัญหาใหญ่กว่าคือตอนนี้ทีมที่ไม่ใช่ Developer ก็ใช้ AI Coding Agent เขียน Code ได้แล้ว และ Agent ที่ไม่มี Guardrail ก็ทำผิดพลาดแบบเดิมได้เหมือนกัน

**Vibe Coding Policy** คือชุด Policy เริ่มต้นสำหรับ Claude Code ที่ออกแบบมาให้ Non-Developer สามารถใช้งานได้อย่างปลอดภัย เพราะ Policy ทำหน้าที่ Enforce แทนคนโดยอัตโนมัติ

---

## ติดตั้งก่อนอ่านต่อ

ถ้าอยากข้ามรายละเอียดและเริ่มใช้งานเลย ทำ 3 ขั้นตอนนี้ใน Claude Code:

```
/plugin marketplace add chinnme/claude-code-vibe-coding-policy
/plugin install vibe-coding-policy@chinnme
/vibe-coding-policy:setup
```

`/vibe-coding-policy:setup` จะพา User ผ่าน installation ทั้งหมด — ถาม scope, copy files, chmod hooks, และติดตั้ง gitleaks ให้

> **ถ้ายังไม่ได้เปิด Claude Code** ให้ทำ step 1-2 ใน session แรก แล้วรัน `/vibe-coding-policy:setup` ได้เลย

---

## Policy นี้มีอะไรบ้าง

ภาพรวมของไฟล์ทั้งหมด:

```
vibe-coding-policy/
├── CLAUDE.md                                  ← กฎที่ Claude อ่านทุก Session
├── .claude-plugin/
│   ├── plugin.json                            ← Plugin identity
│   └── marketplace.json                       ← Marketplace catalog
└── .claude/
    ├── settings.json                          ← Wire Hook ทั้งหมด
    ├── skills/                                ← คำสั่งพิเศษที่พิมพ์ใน Claude Code ได้
    │   ├── setup/                             ← /vibe-coding-policy:setup
    │   ├── new-project/                       ← /vibe-coding-policy:new-project
    │   ├── check-secrets/                     ← /vibe-coding-policy:check-secrets
    │   └── setup-linting/                     ← /vibe-coding-policy:setup-linting
    └── hooks/                                 ← ทำงานอัตโนมัติ ไม่ต้องสั่ง
        ├── session-start-check.sh
        ├── no-hardcoded-secrets.sh
        ├── no-sensitive-files-in-git.sh
        ├── confirm-destructive-ops.sh
        ├── check-public-repo-push.sh
        ├── auto-detect-and-lint.sh
        └── test-hooks.sh
```

Policy แบ่งเป็นสองส่วนหลัก:
1. **CLAUDE.md** ที่เป็น Advisory (Claude อ่านแล้วพยายามทำตาม)
2. **Hooks** ที่เป็น Enforcement (บังคับจริง ไม่มีทางเลี่ยง)

---

## CLAUDE.md — กฎที่ Claude รู้ว่าต้องทำ

`CLAUDE.md` คือไฟล์ที่ Claude Code โหลดเข้า Context ทุกครั้งที่เปิด Session เหมือนกับ Brief ที่ให้พนักงานใหม่อ่านวันแรก — Claude จะรู้ว่ามีกฎอะไรบ้างและพยายามทำตาม

ใน Template นี้มีกฎสำคัญ 4 กลุ่ม:

1. **Security Rules** — ห้าม Hardcode Secret, ต้องมี `.env` ใน `.gitignore`, ห้าม Push ตรงไป `main`, ห้าม Push ไป Public Repo โดยไม่ยืนยัน

2. **Communication** — ทำงานได้เลย ไม่ต้อง Confirm ทุก Step แต่ถ้าไม่แน่ใจให้ถาม และถ้าจะทำอะไรที่ย้อนกลับไม่ได้ต้องบอกก่อน

3. **Code Rules** — ห้าม Suppress Error ด้วย `@ts-ignore` หรือ `eslint-disable`, ห้าม Log ข้อมูลส่วนตัว, ห้าม Bump Dependency โดยไม่บอก

4. **Before Saying Done** — ต้องรัน Test ก่อน, ตรวจว่าไม่มี Secret ใน File ที่แก้, แล้ว Summarize ว่าทำอะไรไปบ้าง

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

**`auto-detect-and-lint.sh`** — ดูนามสกุลไฟล์แล้ว Detect ว่าเป็นภาษาอะไร แล้วรัน Linter ที่เหมาะสมให้อัตโนมัติ ถ้า Linter ไม่ได้ติดตั้ง → ข้ามโดยไม่ Error (Soft Fail)

---

## Skills — คำสั่งพิเศษที่พิมพ์ตรงๆ ใน Claude Code

นอกจาก Hook ที่ทำงานเองแล้ว ยังมี Skill ที่เรียกใช้ได้ตามต้องการ และ Claude จะ Invoke Skill เหล่านี้เองด้วยถ้าเห็นว่า Context เหมาะสม

| พิมพ์ | Claude จะทำอะไร |
|---|---|
| `/vibe-coding-policy:setup` | ติดตั้ง Policy ลงเครื่อง — copy hooks, skills, settings, และ install gitleaks |
| `/vibe-coding-policy:new-project` | Setup Project ใหม่อย่างถูกต้อง — สร้าง `.gitignore`, `.env.example`, Init Git ก่อนเขียน Code บรรทัดแรก |
| `/vibe-coding-policy:check-secrets` | Scan ทุกไฟล์ที่แก้ใน Session นี้อีกรอบ พร้อมตรวจว่า `.gitignore` ครอบคลุมพอไหม |
| `/vibe-coding-policy:setup-linting` | อ่าน `intent.md` / `spec.md` เพื่อ Detect ภาษา แล้ว Guide การติดตั้ง Linter ที่ถูกต้องสำหรับ OS ของ User |

---

## Linting — ทำงานอัตโนมัติหลัง Setup

รัน `/vibe-coding-policy:setup-linting` ครั้งเดียวต่อ Project แล้ว `auto-detect-and-lint.sh` จะ Handle ส่วนที่เหลือให้ทุกครั้งที่ Claude แก้ไฟล์

ภาษาที่รองรับ:

| ภาษา | Linter | Formatter |
|---|---|---|
| Python (`.py`) | Ruff | Ruff |
| JavaScript / TypeScript (`.js`, `.ts`, `.jsx`, `.tsx`) | Biome (Fallback: ESLint) | Biome |
| HTML (`.html`) | HTMLHint | Prettier |
| CSS / SCSS (`.css`, `.scss`) | Stylelint | Prettier |
| Shell (`.sh`, `.bash`) | ShellCheck | shfmt |

---

## ทดสอบว่า Hook ทำงานถูกต้องไหม

Policy นี้มี Test Suite ให้รันหลัง Copy ไปใช้งาน:

```bash
# รัน Test ทุกอย่าง
bash .claude/hooks/test-hooks.sh

# รัน Test เฉพาะ Hook ที่สนใจ
bash .claude/hooks/test-hooks.sh confirm-destructive-ops
bash .claude/hooks/test-hooks.sh check-public-repo-push
```

Test ใช้ Full JSON Input Format ตาม Official Docs ของ Claude Code และมี Live Test กับ GitHub Repo จริง สำหรับ `check-public-repo-push.sh` — ต้องมี Internet

ผ่านแล้ว 52 Tests บน Bash 3.2 (macOS System) และ Bash 5.3 (Linux Equivalent)

---

## ปรับ Policy ให้เหมาะกับ Project ตัวเอง

หลัง Copy `CLAUDE.md` ไปแล้ว เพิ่ม Section เหล่านี้ตามที่มีใน Project:

```markdown
## Commands
- Start: npm start
- Test: npm test
- Lint: npx biome check .    ← เพิ่มหลังรัน /vibe-coding-policy:setup-linting

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

- [AI-Native SDLC Playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) — Anthropic, August 2026
- [Claude Code Hooks Docs](https://code.claude.com/docs/en/hooks)
- [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)
- [gitleaks](https://github.com/gitleaks/gitleaks)