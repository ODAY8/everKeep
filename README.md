# Everkeep

A digital legacy vault: keep important documents and account logins in one private
place, and name the trusted people who should be able to carry out your wishes.

Built with Flutter. The backend is [Supabase](https://supabase.com): Auth, PostgreSQL
with Row Level Security, and Storage. There is no server of our own and no mock data —
if the app isn't connected to Supabase it says so instead of pretending.

## What works today

| Area | What you can do |
|---|---|
| **Account** | Sign up, sign in, sign out, **sign out of all devices**, forgot password → emailed link → set a new password inside the app, change password, change email (confirmed by a link), **delete your account and all your data** |
| **Profile** | Edit name and phone, **change or remove your profile photo**, see last sign-in and live counts |
| **Documents** | Add with a file from your phone (PDF, images, Office, text — up to 25 MB) or as a record only, search, open (short-lived signed link), delete (removes the file too) |
| **Accounts** | Save account logins by category (username only — see *Security notes*), search, favourite, edit, delete |
| **Trusted people** | Invite / remove people, with a relationship and access level |
| **Vault** | One search across documents and accounts, category totals from your real data |
| **Memories & Wishes** | Add a memory or a wish (title, content, an optional date and an optional attached file up to 25 MB), edit, view details, delete, replace or remove just the attachment |
| **Home** | Time-based greeting, real counts, a setup checklist that points at your next step, recent activity from what you really added, and a security score that reflects what is actually set up |
| **Settings** | Your details, **download my data** (JSON to the clipboard), about, log out, delete account |

### Deliberately "Coming soon"

These are labelled as such in the app rather than faked: **Future Messages**,
**two-factor authentication**, **biometric lock**, **emergency-access requests**, and
**push notifications**. Help/legal links appear only when you provide them (see below).

## Set up

1. **Create a Supabase project** (dashboard → New project).
2. **Apply all three migrations**, in order, in the dashboard's *SQL Editor* (or
   `supabase db push` with the Supabase CLI):
   1. [`supabase/migrations/20260921000000_initial_schema.sql`](supabase/migrations/20260921000000_initial_schema.sql)
      — tables, Row Level Security, the sign-up trigger, and the private `documents` bucket.
   2. [`supabase/migrations/20260922000000_account_management.sql`](supabase/migrations/20260922000000_account_management.sql)
      — the `delete_my_account()` function (used by *Delete Account*) and the public `avatars`
      bucket (profile photos, 2 MB, images only, each user limited to their own folder).
   3. [`supabase/migrations/20260923000000_memories_and_wishes.sql`](supabase/migrations/20260923000000_memories_and_wishes.sql)
      — the `memories_wishes` table and the private `memories` bucket (attachments, 25 MB, each
      user limited to their own folder) that back the Memories tab.

   Without the second one, deleting an account and profile photos will report an error. Without the
   third, the Memories tab's "Add" will fail with a database error (delete_my_account() still works —
   the table's foreign key cascades on account deletion once the migration exists).
3. **Allow the email links to open the app.** Authentication → *URL Configuration* → *Redirect URLs* →
   add `com.example.everkeep://login-callback/` (or your own value — see `AUTH_REDIRECT_URL`).
   Confirmation and password-reset emails link back through this address.
4. **Choose email-confirmation behaviour** (Authentication → *Sign In / Providers* → Email).
   With *Confirm email* **on** (the default), sign-up creates the account and the app tells the user
   to confirm their address, then sign in. With it **off**, sign-up signs the user in straight away.
   Both are handled. (Supabase's built-in mailer is heavily rate-limited; configure custom SMTP before
   real users arrive.)
5. **Add your settings.** Copy the template and fill in the two values from
   *Project Settings → API Keys* (the **publishable** key, not a secret key):

   ```bash
   cp .env.example .env
   ```

   ```
   SUPABASE_URL=https://<your-project-ref>.supabase.co
   SUPABASE_PUBLISHABLE_KEY=<your publishable key>
   ```

   Optional: `SUPPORT_EMAIL`, `HELP_URL`, `TERMS_URL`, `PRIVACY_URL` (shown in Settings only when
   set) and `AUTH_REDIRECT_URL`. `.env` is git-ignored. **Never** put a secret key, service-role key
   or database password in the app — it refuses to start if it is given one.
6. **Run it:**

   ```bash
   flutter pub get
   run.cmd                       # Windows: passes .env for you (run.cmd -d <device-id> to pick a phone)
   flutter run --dart-define-from-file=.env     # anywhere else
   ```

   Without valid settings the app shows an "Everkeep isn't connected yet" screen instead of running
   on fake data.

### On a phone (wireless debugging)

Settings → Developer options → *Wireless debugging* → pair, then `flutter devices` and
`run.cmd -d <id>`. Prefer this to a cable for the first install: a large debug build can drop a USB link.

### Smooth performance

Flutter's **debug** build is deliberately slow (it compiles on the fly and checks everything), so it
will stutter on a real phone. Judge speed from a release build:

```bash
run.cmd --release -d <device-id>
```

The app is built to stay light: fonts and images are bundled (no downloads while scrolling), photos are
resized before upload, list animations are capped so long lists don't stagger, and the vault totals are
fetched in parallel.

## Test

```bash
flutter analyze
flutter test                     # app, providers, screens, and the Supabase services (HTTP faked)
bash supabase/tests/run.sh       # schema + Row Level Security, on a throwaway Postgres in Docker
```

`supabase/tests/run.sh` (needs Docker running) applies all the migrations and then acts as two different users
(and an anonymous one), checking that nobody can read or change anyone else's rows or files, that a client
can't mark its own document "verified", and that account deletion only ever removes the caller's data. It uses a
small stand-in for Supabase's `auth`/`storage` schemas, so it verifies the policy logic; it does not replace
trying the app against your real project.

## Deploy checklist

Do these before publishing to a store:

- [ ] **Change the application id.** It is still `com.example.everkeep` (`android/app/build.gradle.kts`,
      `AndroidManifest.xml`, and the bundle id / URL scheme in `ios/Runner`). Google Play rejects
      `com.example.*`. If you change it, update the email-link scheme too (`AUTH_REDIRECT_URL`, manifest,
      Info.plist, and the Supabase Redirect URL).
- [ ] **Sign the release build.** Create an upload key and `android/key.properties`
      (template: [`android/key.properties.example`](android/key.properties.example)). Both are git-ignored.
      Keep the key safe: if you lose it you can't update the app.
- [ ] **App icon and name.** Replace the default launcher icon (e.g. with `flutter_launcher_icons`).
- [ ] **Add your support and legal links** (`SUPPORT_EMAIL`, `TERMS_URL`, `PRIVACY_URL`). Stores require a
      privacy policy, and one must explain that account deletion is in *Settings → Delete Account*.
- [ ] **Custom SMTP** for Supabase auth emails, and consider CAPTCHA and leaked-password protection.
- [ ] **Bump `version:`** in `pubspec.yaml` for each release.
- [ ] Build:

  ```bash
  flutter build appbundle --release --dart-define-from-file=.env     # Google Play
  flutter build apk --release --target-platform android-arm64 --dart-define-from-file=.env   # a file to sideload
  ```

  (The values in `.env` must be passed to every release build too.)

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
  profile and dashboard data; on sign-out — or when the backend ends the session (expiry, revocation,
  sign-out elsewhere) — it resets every user-scoped provider so the next user never sees the previous
  user's data. It also opens the "set a new password" screen when a reset link is followed.
  `AuthGuard` keeps signed-out users off protected screens.
- **`lib/core/config/`** — build-time settings (`SupabaseConfig`, `AppLinks`, `AuthRedirect`) and the
  startup error screen.

### Data model

| Table / bucket | Holds | Notes |
|---|---|---|
| `profiles` | name, phone, avatar URL | one row per user (`id` = auth user id); created by a trigger at sign-up. Email stays in Supabase Auth. |
| `security_settings` | 2FA / biometric / login-alert preferences | one row per user; **default off**. Not used by the UI yet (those features are "Coming soon"). |
| `documents` | title, category, file path/size | file bytes live in Storage; `is_verified` can't be set by clients |
| `accounts` | name, username, category, favourite | **no secret column** — see below |
| `trusted_contacts` | name, relationship, access level | |
| `memories_wishes` | title, content, memory/wish, optional date, optional file path/size | powers the Memories tab |
| `documents` bucket | your uploaded files | **private**; opened only through short-lived signed links |
| `memories` bucket | memory/wish attachments | **private**; same pattern as `documents` |
| `avatars` bucket | profile photos | public read (an avatar has to load in an `<Image>`); writes limited to your own `<user id>/` folder |

Every table has Row Level Security with owner-only policies for each operation, keyed on `auth.uid()`.
Document and memory files live under `<user id>/documents/…` and `<user id>/memories/…` respectively,
with matching Storage policies — a row can only point into its owner's own folder. Deleting a document
or a memory/wish removes its file too; deleting an account removes every file first (across all three
buckets) and only then the account (if any file can't be removed, the account is kept and you're told).

### Conventions

- A failed **first load** replaces a list with an error and a *Try again* button. A failed
  **add / delete / toggle** leaves the list alone and reports the error in a snackbar; forms stay open
  with the user's input. An update that matched no row is reported as a failure, never as success.
- Providers guard against late results with `SessionScoped`, so a request started before sign-out
  can't land in the next session.
- **Honest UI:** every control does what it says, or it isn't there, or it says "Coming soon". Nothing
  reports success unless Supabase did.

## Security notes — read before shipping

- **Vault secrets are not stored.** `accounts` keeps a name, username and category only. Storing
  passwords needs client-side encryption (a key derived from a user-held passphrase, with per-item
  nonces and stored KDF parameters) so the server never sees plaintext. Do not add a plaintext
  password column. Until then, Everkeep is a place for *where things are*, not a password manager.
- **Data is protected by Row Level Security and Supabase's encryption at rest**, not client-side
  encryption; the app doesn't claim otherwise. Documents are private files, opened through signed links
  that expire.
- **The security score** on Home/Profile/Security counts safeguards that are really in place (confirmed
  email, at least one trusted person, a protection switched on). It measures setup, not a guarantee.
- **Two-factor and biometric lock are not built.** They need Supabase MFA and `local_auth`; the app labels them
  "Coming soon".
- **Session tokens are stored by `supabase_flutter` in `SharedPreferences`** (unencrypted). For a
  vault app, supply a `LocalStorage` backed by `flutter_secure_storage`.
- **Sign-out** clears the device's session first and then revokes it on the server. If the device is
  offline at that moment, the server-side refresh token stays valid until it expires. *Sign out of all
  devices* tells you plainly if the other devices couldn't be reached.
- **Profile photos are public-by-URL** (a random-looking path under your user id, but not secret). Don't
  treat an avatar as private.
- **"Download my data"** copies your data as JSON to the clipboard; other apps can read the clipboard, so
  clear it after pasting.
- Consider lowering `file_size_limit` / adding `allowed_mime_types` on the `documents` and `memories` buckets to what you
  really accept.
