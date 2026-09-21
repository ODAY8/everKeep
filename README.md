# Everkeep

A digital legacy vault: keep documents, account logins, memories and messages
safe, and choose the trusted people who can carry out your wishes.

The backend is [Supabase](https://supabase.com): Auth, PostgreSQL with Row Level
Security, and private Storage.

## Set up

1. **Create a Supabase project** (dashboard → New project).
2. **Apply the schema.** Run
   [`supabase/migrations/20260921000000_initial_schema.sql`](supabase/migrations/20260921000000_initial_schema.sql)
   in the dashboard's *SQL Editor* (or `supabase db push` with the Supabase CLI).
   It creates the tables, Row Level Security policies, the sign-up trigger and the
   private `documents` storage bucket.
3. **Choose your email-confirmation behaviour** (Authentication → Sign In / Providers → Email).
   With *Confirm email* **on** (the default), sign-up creates the account and the app tells the
   user to confirm their address, then sign in. With it **off**, sign-up signs the user in
   straight away. Both are handled.
4. **Add your settings.** Copy the template and fill in the two values from
   *Project Settings → API Keys* (the **publishable** key, not a secret key):

   ```bash
   cp .env.example .env
   ```

   ```
   SUPABASE_URL=https://<your-project-ref>.supabase.co
   SUPABASE_PUBLISHABLE_KEY=<your publishable key>
   ```

   `.env` is git-ignored. **Never** put a secret key, service-role key or database password in
   the app — the app refuses to start if it is given one.
5. **Run it:**

   ```bash
   flutter pub get
   flutter run --dart-define-from-file=.env
   ```

   (VS Code: the included launch configuration already passes the file.) Without valid
   settings the app shows a "not connected" screen instead of running on fake data.

## Test

```bash
flutter analyze
flutter test                     # app, providers, and the Supabase services (HTTP faked)
bash supabase/tests/run.sh       # schema + Row Level Security, on a throwaway Postgres in Docker
```

`supabase/tests/run.sh` applies the migration and then acts as two different users (and an
anonymous one), checking that nobody can read or change anyone else's rows or files. It uses a
small stand-in for Supabase's `auth`/`storage` schemas, so it verifies the policy logic; it does not
replace trying the app against your real project.

## Architecture

```
Screen  →  Provider (ChangeNotifier)  →  Repository  →  Service  →  Supabase
                                                                      ├─ Auth
                                                                      ├─ PostgreSQL (RLS)
                                                                      └─ Storage
```

- **`lib/providers/`** hold UI state (`isLoading`, `error`, `hasFetched`, the data). Each takes its
  repository in the constructor, so tests inject fakes (`test/fakes.dart`).
- **`lib/repositories/`** are thin abstractions over services.
- **`lib/services/`** talk to Supabase. Each takes an optional `SupabaseClient` (defaults to the
  shared one) so tests can drive them against a faked HTTP layer.
- **`lib/core/supabase/`** — `AppSupabase` initialises Supabase once and hands out the client;
  `supabase_errors.dart` turns every Auth / database / Storage / network failure into a safe,
  user-readable `BackendException` (raw errors can reveal schema details, so they never reach the UI).
- **`lib/core/session/`** keeps providers consistent with who is signed in: on sign-in it loads the
  profile and dashboard data; on sign-out — or when the backend ends the session (expiry,
  revocation, sign-out elsewhere) — it resets every user-scoped provider so the next user never sees
  the previous user's data. `AuthGuard` keeps signed-out users off protected screens.

### Data model

| Table | Holds | Notes |
|---|---|---|
| `profiles` | name, phone, avatar | one row per user (`id` = auth user id); created by a trigger at sign-up. Email stays in Supabase Auth. |
| `security_settings` | 2FA / biometric / login-alert preferences | one row per user; **default off** |
| `documents` | title, category, file path/size | file bytes live in Storage; `is_verified` can't be set by clients |
| `accounts` | name, username, category, favorite | **no secret column** — see below |
| `trusted_contacts` | name, relationship, access level | |

Every table has Row Level Security with owner-only policies for each operation, keyed on `auth.uid()`.
Documents' files are in the private `documents` bucket under `<user id>/documents/…`, with matching
Storage policies; a document row can only point into its owner's folder.

### Conventions

- A failed **first load** replaces a list with an error and a *Try again* button. A failed
  **add / delete / toggle** leaves the list alone and reports the error in a snackbar; forms stay open
  with the user's input. An update that matched no row is reported as a failure, never as success.
- Providers guard against late results with `SessionScoped`, so a request started before sign-out
  can't land in the next session.

## Security notes — read before shipping

- **Vault secrets are not stored.** `accounts` keeps a name, username and category only. Storing
  passwords needs client-side encryption (a key derived from a user-held passphrase, with per-item
  nonces and stored KDF parameters) so the server never sees plaintext. Do not add a plaintext
  password column.
- **The UI still says "end-to-end zero-knowledge encryption"** on the Security screen and "Vault
  score: strong" on Profile. Neither is true of the current design (data is protected by RLS and
  Supabase's encryption at rest, not client-side encryption). Change that copy before release.
- **The security toggles are stored preferences, not enforcement.** Switching on "Two-Factor
  Authentication" saves a flag; it does not enroll an authenticator (that needs Supabase MFA), and
  "Biometric Lock" needs on-device support (`local_auth`). The dashboard's security score is just the
  share of these preferences that are on.
- **Session tokens are stored by `supabase_flutter` in `SharedPreferences`** (unencrypted). For a
  vault app, supply a `LocalStorage` backed by `flutter_secure_storage`.
- **Sign-out:** the SDK clears the device's session first and then revokes it on the server. If
  the device is offline at that moment, the server-side refresh token stays valid until it expires.
- **Password reset:** the app requests the recovery email, but setting the new password needs a deep
  link (or hosted page) configured under Authentication → URL Configuration. It is not wired up yet.
- **File upload has no picker yet.** The service/repository/provider support uploading to private
  Storage (and signed download links), but no screen offers file selection — that needs a file-picker
  package and a UI change.
- Consider allow-listing `allowed_mime_types` and lowering `file_size_limit` on the `documents`
  bucket, and enabling Supabase's leaked-password protection and CAPTCHA for sign-up.

## Still placeholders in the UI

Some display text is still static: the Home "Recent activity" list, Profile's "Legacy Prefs",
"Last login 2h ago" and "Premium" subscription rows, and the Home hero card's "3 tasks remaining".
Financials, messages and memories aren't built and report zero in the vault totals.

Fonts are downloaded at runtime by `google_fonts` (network access is declared for Android and macOS);
bundle Figtree and Young Serif as assets for a fully offline first launch.
