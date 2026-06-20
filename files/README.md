# Dig Pro — Deploy & Sign-in Setup

A single-file Gin scorepad. It runs fully on its own (scores saved on each device).
Adding Supabase turns on **real email sign-in**, **cloud save**, and **league-only sharing**.

You only need to do this once. Budget ~15 minutes.

---

## Files

- **index.html** — the whole app (HTML + CSS + JS in one file).
- **supabase-setup.sql** — the database tables + security rules. Run once.

---

## Part A — Put it online (no sign-in yet)

The app works immediately as a static site; sign-in is added in Part B.

### Option 1 — GitHub + Vercel (recommended, auto-redeploys)
1. Go to **github.com** → **New repository** → name it `dig-pro` → **Create**.
2. In the repo → **Add file → Upload files** → drag in `index.html` → **Commit**.
   (Keep the name exactly `index.html`, at the repo root.)
3. Go to **vercel.com** → **Add New → Project** → **Import** the `dig-pro` repo
   (authorize GitHub if asked).
4. Leave defaults (Framework: **Other**, no build command) → **Deploy**.
5. Copy your live URL, e.g. `https://dig-pro.vercel.app`.

### Option 2 — Vercel CLI
In a folder containing only `index.html`:
```
npx vercel login
npx vercel --prod
```
Accept the defaults; it prints your URL.

At this point the site works and saves locally. The footer shows **Sign in**, but it
will say "cloud not configured" until Part B.

---

## Part B — Turn on sign-in + cloud (Supabase)

### 1. Create the project
1. Go to **supabase.com** → sign up / log in → **New project**.
2. Pick a name and a strong database password → **Create**. Wait ~1 min for it to spin up.

### 2. Create the database
1. In the project, open **SQL Editor** (left sidebar) → **New query**.
2. Open `supabase-setup.sql`, copy everything, paste it in, click **Run**.
3. You should see "Success". (This creates the tables and the security rules.)

### 3. Get your two keys
1. Go to **Project Settings** (gear icon) → **API**.
2. Copy the **Project URL** (looks like `https://abcd1234.supabase.co`).
3. Copy the **anon public** key (a long string). This one is safe to put in the
   front-end — the database security rules protect your data.

### 4. Put the keys in the app
1. Open `index.html` in any text editor.
2. Near the top of the `<script>` find these two lines:
   ```js
   const SUPABASE_URL = "";
   const SUPABASE_ANON_KEY = "";
   ```
3. Paste your values inside the quotes:
   ```js
   const SUPABASE_URL = "https://abcd1234.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOi...your-anon-key...";
   ```
4. Save the file.

### 5. Allow your site to receive the sign-in link
1. In Supabase → **Authentication** → **URL Configuration**.
2. Set **Site URL** to your live URL (e.g. `https://dig-pro.vercel.app`).
3. Under **Redirect URLs**, add the same URL (and `http://localhost:3000` if you
   test locally). Save.

### 6. Re-deploy with the keys
- **GitHub path:** upload the edited `index.html` to your repo again (Add file →
  Upload files → Commit). Vercel auto-redeploys in ~20s.
- **CLI path:** run `npx vercel --prod` again.

---

## Part C — Test it
1. Open your live URL.
2. Footer → **Sign in** → enter your email → **Email me a sign-in link**.
3. Check your inbox, tap the link — it returns you to the app, now signed in
   (your email shows in the footer).
4. Open **Rules**, change something — it's now saved to your account.
5. Create a **league**, play and finish a game — it saves to the cloud.
6. Have a friend open the same URL, sign in, and **Join by code…** with your
   league's code. They'll see the league's games; private games stay private.

---

## How sharing works (the important bit)
- Games **filed under a league** are visible to everyone who has joined that league.
- Games left under **"All games / no league"** are private to you.
- This is enforced by the database itself (row-level security), not just the app —
  so nobody can read another person's private games even with the public key.

---

## Troubleshooting
- **Footer still says "cloud not configured"** → the two keys weren't saved/redeployed,
  or there's a typo in the URL/key. Re-check Part B step 4 and redeploy.
- **No sign-in email** → check spam; confirm the email is valid. Supabase's built-in
  email is rate-limited (a few per hour) — fine for testing.
- **Clicking the link doesn't sign me in** → the URL isn't in Supabase **Redirect URLs**
  (Part B step 5). Add the exact deployed URL and try again.
- **"No league with that code"** → codes are case-insensitive but must match; make sure
  the friend is signed in before joining.
- **Errors in the browser console** → send them over and I'll fix the integration.

## Notes for real-world use
- For reliable email at volume, add your own SMTP provider in Supabase →
  **Authentication → Emails** (e.g. Resend, Postmark, SendGrid). Optional for casual use.
- Supabase and Vercel both have free tiers that comfortably cover a game-night app.
- "Clear all data" in the footer only clears this device's local copy; your cloud
  account data is untouched.
