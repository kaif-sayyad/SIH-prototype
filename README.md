++# SkillPath Family Counselling Portal

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

## Flutter App — Full Backend Conversion

The entire Next.js backend is converted to Dart and runs **locally inside the Flutter app** (`flutter_app/`). No Node.js server is required — the app is fully self-contained.

### Backend → Flutter mapping

| Next.js Backend (TypeScript) | Flutter Port (Dart) |
|---|---|
| `lib/config.ts` | `flutter_app/lib/backend/config_service.dart` |
| `lib/db.ts` (JSON DB + SQL wrapper + vector search) | `flutter_app/lib/backend/database_service.dart` |
| `lib/auth.ts` (HMAC hashing, parent codes, session tokens) | `flutter_app/lib/backend/auth_service.dart` |
| `lib/gemini.ts` (embeddings, JSON generation, health test) | `flutter_app/lib/backend/gemini_service.dart` |
| `lib/rag/ingest.ts` (CSV normalization, chunking, indexing) | `flutter_app/lib/backend/rag/ingest_service.dart` |
| `lib/rag/retrieval.ts` (entity extraction, hybrid retrieval) | `flutter_app/lib/backend/rag/retrieval_service.dart` |
| `lib/rag/grounded-gen.ts` (grounded generation) | `flutter_app/lib/backend/rag/grounded_gen_service.dart` |
| `lib/rag/verification.ts` (hallucination guard, RAG pipeline) | `flutter_app/lib/backend/rag/verification_service.dart` |
| `lib/agent/tools.ts` (concern classifier, recommend, escalate) | `flutter_app/lib/backend/agent/tools_service.dart` |
| `lib/agent/runner.ts` (agentic counsellor loop) | `flutter_app/lib/backend/agent/runner_service.dart` |
| `app/api/auth/*` | `flutter_app/lib/backend/api/auth_api.dart` |
| `app/api/session` | `flutter_app/lib/backend/api/session_api.dart` |
| `app/api/concerns/resolve` | `flutter_app/lib/backend/api/concerns_api.dart` |
| `app/api/counsellor/*` | `flutter_app/lib/backend/api/counsellor_api.dart` |
| `app/api/admin/*`, `app/api/dataset/*` | `flutter_app/lib/backend/api/admin_api.dart` |

### Flutter backend features
- **Local JSON database** (`database_service.dart`) — full port of the record schema (users, sessions, concerns, sentiment_shifts, outcomes, outcome_chunks, escalations, datasets, coverage_gaps, engagement) with the SQL-compatibility query wrapper and cosine-similarity vector search. Persists to `<app_documents>/db/db.json` via `path_provider`.
- **Knowledge base** — `knowledge/outcomes.csv` and `knowledge/guides/faq.md` are bundled as Flutter assets (`flutter_app/assets/knowledge/`) and ingested on first launch exactly like the backend's `loadKnowledgeFiles()`.
- **Auth** — HMAC-SHA256 password hashing, 10+ char Parent Access Code generation/regeneration, signed session tokens (Base64 + HMAC signature), lockout after 5 failed attempts.
- **Agentic AI counsellor** — safety rules (human-counsellor requests, safety/social topics), concern classification, RAG retrieval, grounded generation with the number-level verification guard and retry, automatic escalation with sentiment-shift tracking.
- **Admin analytics** — live funnel, resistance-by-district, concern distribution, sentiment shifts, demo-data generation, knowledge re-index, dataset upload, and Gemini health check.

### Running the Flutter app
```bash
cd flutter_app
flutter pub get
flutter run
```
Configuration lives in `flutter_app/assets/config.json` (same keys as the root `config.json`).

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
