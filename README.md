# Soul-Pal — Global Engineering Guide (Supabase Edition, Read Me First)

This document is the **single source of truth**. Cursor must read and obey this before any task.

---

## 0) Mission & Non-Goals

**Mission:**  
iOS-only SwiftUI app with two tiers:
- **Free:** curated affirmations (no AI).
- **Paid:** one active **weekly mood session** with category-based affirmations and scheduled push notifications (1–4/day).

**Non-Goals (do NOT implement):**
- No AI/LLM generation, chat, or social features.
- No Android/iPad/Mac/Web client.
- No complex CMS UI; use CSV/JSON import or Retool.
- No experimental/novel architectures; keep it pragmatic.

---

## 1) Tech Stack (fixed)

**iOS (SwiftUI, iOS 17+)**
- SwiftUI, Combine, async/await, StoreKit 2.
- Supabase Swift client for Auth & PostgREST.
- APNs for push (token-based auth).
- Localization: EN/TR.

**Backend (Supabase)**
- Supabase Auth (GoTrue): Apple, Google, Email/Password.
- Postgres + Row Level Security (RLS).
- Edge Functions (Deno) for APIs, webhooks, APNs sender.
- Cron/Scheduled Functions (or `pg_cron`) for jobs.
- Storage (optional) for exports.

**Observability**
- Minimal: structured logs from Edge Functions.
- (Optional) Sentry for crash/perf on iOS; or Apple MetricKit.
- Analytics: simple events table in Postgres (see §11).

**Do not add** other libs unless explicitly allowed.

---

## 2) High-Level Architecture

iOS App (Supabase Swift, StoreKit 2)  
↔ **Edge Functions** (`/functions/v1/*`) — business logic, APNs sender, App Store Server Notifications  
↔ **Postgres** (RLS-protected tables)  

Admin content via CSV/JSON import → Edge Function → tables.  
Push is direct **APNs** from Edge Function (token-based). No FCM.

---

## 3) Canonical Data Model (Postgres tables)

> Prefix user-owned tables with `app_`. System/ops tables can use `ops_`.

**app_users** (1:1 with auth user)
- `user_id PK uuid` (auth.uid)
- `locale text`, `timezone text`
- `is_subscriber bool` (derived by backend)
- `created_at timestamptz`

**app_profiles**
- `user_id PK uuid FK -> app_users`
- `name text`, `nickname text`
- `date_of_birth date`, `birth_hour smallint null`

**app_subscriptions**
- `user_id PK uuid`
- `apple_original_transaction_id text`
- `status text` (active|grace|lapsed|revoked)
- `renews_at timestamptz null`, `revoked_at timestamptz null`
- `last_verified_at timestamptz`, `reason text`

**app_affirmation_categories**
- `id PK uuid`, `key text`, `locale text`, `is_active bool`

**app_affirmations**
- `id PK uuid`, `category_id uuid FK`, `text text`
- `locale text`, `intensity smallint check 1..3`
- `tags text[]`, `is_active bool`, `last_used_at timestamptz null`

**app_device_tokens**
- `id PK uuid`, `user_id uuid`, `token text unique`, `bundle_id text`
- `platform text default 'ios'`, `is_active bool`, `updated_at timestamptz`

**app_notification_preferences**
- `user_id PK uuid`, `frequency smallint check 1..4`
- `quiet_start time`, `quiet_end time`, `allow_push bool`

**app_mood_sessions**
- `id PK uuid`, `user_id uuid`, `category_id uuid`
- `status text` (active|completed|cancelled)
- `started_at timestamptz`, `ends_at timestamptz`
- `frequency_per_day smallint check 1..4`
- **Constraint:** one active per user.

**app_notification_schedules**
- `id PK uuid`, `user_id uuid`, `mood_session_id uuid null`
- `scheduled_at timestamptz`, `payload_ref uuid null`
- `status text` (scheduled|sent|failed|skipped)
- `created_at timestamptz`

**app_sent_logs**
- `id PK uuid`, `schedule_id uuid`, `sent_at timestamptz`
- `apns_id text`, `result text`, `error_code text null`

**analytics_events** (simple)
- `id PK uuid`, `user_id uuid null`, `name text`, `props jsonb`, `ts timestamptz`

**Indexes (must)**
- `app_affirmations(category_id, locale, is_active)`
- `app_notification_schedules(user_id, scheduled_at, status)`
- `app_sent_logs(schedule_id)`
- `app_mood_sessions(user_id, status)`

---

## 4) RLS Policies (summary)

- Enable RLS on **all app_*** tables.
- **Owner read/write:** rows filtered by `auth.uid() = user_id`.
- **Content tables** (`app_affirmation_categories`, `app_affirmations`): read for all authenticated users; write only for service role.
- **Schedules & logs:** user can read their own; write only via service role/Edge Functions.
- **Subscriptions:** read own; write service role.
- **Device tokens & prefs:** read/write own; write service role allowed.

> All mutations from iOS go through **stored procedures or Edge Functions** when business rules are needed.

---

## 5) API Surface (Edge Functions)

Base path: `/functions/v1/*`

**User/Profile**
- `GET  /me` → profile + entitlement
- `PUT  /profile` → name/nickname/DOB/birth_hour
- `PUT  /prefs/notifications` → frequency, quiet hours, allow_push
- `POST /device/register` → store APNs token (+bundle)

**Content**
- `GET  /content/categories?locale=xx`
- `GET  /content/affirmations/free?locale=xx&limit=20` (randomized; updates `last_used_at`)
- Admin: `POST /admin/affirmations/import` (CSV/JSON), `PUT /admin/affirmations/:id`

**Mood Sessions (paid)**
- `POST /moods/start` `{ category_id, frequency }`  (enforce one-active)
- `POST /moods/end` `{ session_id, reason }`
- `GET  /moods/active`

**Subscriptions**
- `POST /subs/verify`  (App Store Server API)
- `POST /subs/assn`    (App Store Server Notifications v2 webhook)
  - Updates `app_subscriptions` and `app_users.is_subscriber`

**Notifications**
- `POST /notify/test` (for user to test)
- Jobs:
  - **scheduler** (cron or trigger on prefs/session change): compute next send times in user's timezone respecting quiet hours.
  - **sender** (cron, e.g., every minute): send due APNs, log results, retry/backoff.

---

## 6) Notifications — Exact Rules

- Default window: **10:00–21:00 user local time**.
- Respect **quiet hours**; if inside, **shift** to next allowed slot.
- **Frequency 1–4/day**; evenly spread.
- **No repeat** same affirmation to same user within **30 days** (check history).
- Mood session content takes effect **next scheduled slot**.
- Delivery target: **≥95% success**, P95 latency **< 5 min** at target load.

**APNs Auth**
- Use **token-based** (P8). Keep `APNS_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_ENV` in Supabase secrets.

---

## 7) Subscriptions — Exact Rules

- One monthly auto-renewable product.
- Verify receipts via **App Store Server API** in an Edge Function.
- Process **ASSN v2** webhook: update `status/renews_at/is_subscriber` within **60s**.
- Entitlement **authoritative on server**; device caches but must confirm with `/me`.

Secrets: `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`, `APP_BUNDLE_ID`, `SUB_PRODUCT_ID`.

---

## 8) iOS App — Folder Layout 