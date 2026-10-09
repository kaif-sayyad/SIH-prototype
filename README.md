# SkillPath Family Counselling Portal

AI-enabled career counselling and family decision-support platform for vocational education (MSDE Problem Statement).

---

## Quick Start & Running Instructions

### 1. Installation
```bash
npm install
```

### 2. Configure Gemini API Key & Secrets (`config.json`)
Create `config.json` in the project root:
```json
{
  "GEMINI_API_KEY": "PASTE_YOUR_GEMINI_API_KEY_HERE",
  "GEMINI_MODEL": "gemini-2.5-flash",
  "GEMINI_EMBEDDING_MODEL": "gemini-embedding-001",
  "ADMIN_EMAIL": "admin@example.com",
  "ADMIN_PASSWORD": "CHANGE_ME",
  "SESSION_SECRET": "CHANGE_ME_TO_A_LONG_RANDOM_STRING",
  "PORT": 3000
}
```
*Note: With a placeholder key, the app runs cleanly, displays "AI key not set" in the bot & admin page, and provides evidence-grounded answers from the `knowledge/` files only.*

### 3. Run Development Server
```bash
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

### 4. Run Test Suite
```bash
npm test
```

---

## How Parent Access Codes Work
- **Student Registration**: When a student registers with their name, mobile, and password, a unique 10+ character **Parent Access Code** (e.g. `SP-7K3M-9QX2`) is automatically generated and displayed with a Copy button.
- **Student Login**: Student logs in using Mobile Number + Password. They can view or regenerate their Parent Access Code at any time (invalidating old codes immediately).
- **Parent Login**: Parent logs in using the Parent Access Code + Parent Name. This opens the linked student's portfolio (profile, family context, recommendations, pathway, concern statuses, summary, and shared conversation history).
- **Shared Counselling Session**: Both student and parent share a single counselling session. All messages are transparently tagged as `Student` or `Parent`.

---

## How to Edit Knowledge Files
The outcome database is driven by verified files in the `knowledge/` folder:
- `knowledge/outcomes.csv`: Contains trade, provider, location/district, placement_rate, avg_earnings, nsqf_level, duration_months, training_cost, min_education, job_roles, progression, further_education, source, and data_date.
- `knowledge/academic_path.csv`: Contains academic comparison data.
- `knowledge/guides/*.md`: FAQ guides and parent concern resolution guides.

*To update data:* Simply edit or add rows to `knowledge/outcomes.csv` or add `.md` files in `knowledge/guides/`. Click **Reload Knowledge** in the Admin Dashboard to re-index immediately without restarting.

---

## How This Meets the Problem Statement

| Problem Statement Requirement | Screen / Component / File Delivering It |
|---|---|
| **7-Step Journey & Government Portal Design** | `app/page.tsx`, `style.css` (Steps 1–7 top task bar, government masthead, fixed bottom AI bot) |
| **Parent Portfolio Access & Parent Access Code** | `lib/auth.ts`, `app/api/auth/register/route.ts`, `app/api/auth/parent-code/route.ts` |
| **Gemini API & Config File** | `config.json`, `lib/config.ts`, `lib/gemini.ts` |
| **Verified Outcome Data & RAG Backend** | `knowledge/outcomes.csv`, `knowledge/guides/`, `lib/rag/ingest.ts`, `lib/rag/retrieval.ts` |
| **Number Verification Guard (No Invented Figures)** | `lib/rag/verification.ts` (`verifyAnswerGrounding`, `extractNumbersFromText`) |
| **Agentic AI Tool Loop** | `lib/agent/runner.ts`, `lib/agent/tools.ts` |
| **Concern-Resolution Loop & Yes/Partly/No** | `app/page.tsx` (Step 4), `app/api/concerns/resolve/route.ts` |
| **Sentiment & Engagement Tracking** | `lib/db.ts` (`sentiment_shifts`), `app/api/concerns/resolve/route.ts` |
| **Admin Dashboard & Resistance by District** | `app/api/admin/analytics/route.ts`, `app/page.tsx` (Step Admin) |
| **Human Counsellor Escalation & Inbox** | `app/api/counsellor/inbox/route.ts`, `app/page.tsx` (Counsellor Inbox tab) |
| **Regional Languages & Low-Literacy Support** | `public/i18n/en.json`, `public/i18n/mr.json`, Web Speech API voice/audio synthesis |
| **Privacy & Responsible AI** | Hashed passwords, zero raw message text in analytics, role-based authorization |
