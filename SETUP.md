# Out of Bounds Rewards — Setup Guide

A loyalty scheme across **LevelUp Escapes**, **The Axe Factor** and **XscapeNow**.
Customers collect **6 stamps → £25 off** (redeemable at any one site), and get **5% off** for signing up.

There are two parts:
1. **Supabase** — the secure database that stores accounts and stamps (free).
2. **The web app** — a Progressive Web App customers add to their home screen, plus a staff panel.

Total setup time: ~20 minutes. No coding needed.

---

## Step 1 — Create a free Supabase project

1. Go to **https://supabase.com** → sign up (free) → **New project**.
2. Give it a name (e.g. `oob-rewards`), set a database password (save it somewhere), pick the London region.
3. Wait ~2 minutes for it to spin up.

## Step 2 — Create the database

1. In your project, open **SQL Editor** (left sidebar) → **New query**.
2. Open the file **`supabase/schema.sql`** from this project, copy *everything*, paste it in, and click **Run**.
3. You should see "Success". This creates all the tables, security rules, and the staff functions.

> This also creates a default staff PIN of **1234**. Change it in Step 6.

## Step 3 — Turn off email confirmation (recommended for fast signup)

So customers get their card instantly without clicking an email link:

1. Go to **Authentication → Providers → Email**.
2. Turn **OFF** "Confirm email".
3. Save.

(If you'd rather customers confirm their email first, leave it on — the app handles both.)

## Step 4 — Get your two keys

1. Go to **Project Settings → API**.
2. Copy the **Project URL** (looks like `https://abcd1234.supabase.co`).
3. Copy the **anon public** key (the long one labelled `anon` `public`).

You'll paste these into Vercel in Step 7 — **not** into any file in the repo.

## Step 5 — (Nothing to edit)

Keys now load from Vercel's environment variables via a small serverless
function at `api/config.js`. There is no `config.js` to edit and nothing
sensitive ever goes into your repo.

## Step 6 — Change the staff PIN

1. Back in Supabase **SQL Editor**, run this (change `1234` to your real PIN):

```sql
update public.staff
set pin_hash = crypt('YOUR-NEW-PIN', gen_salt('bf'))
where name = 'Front Desk';
```

To add a PIN per team member (so the audit log shows who added each stamp):

```sql
insert into public.staff(name, pin_hash) values ('Ash',     crypt('2468', gen_salt('bf')));
insert into public.staff(name, pin_hash) values ('Adrian',  crypt('1357', gen_salt('bf')));
```

## Step 7 — Deploy to GitHub + Vercel

**Push to GitHub:**
```bash
cd loyalty
git init
git add .
git commit -m "Out of Bounds Rewards"
git remote add origin https://github.com/nathgreen2111/oob-rewards.git
git push -u origin main
```

**Deploy on Vercel:**
1. Go to **https://vercel.com** → sign in with GitHub → **Add New → Project**.
2. Import the `oob-rewards` repo.
3. Before deploying, open **Environment Variables** and add the two from Step 4:
   - `SUPABASE_URL` = your project URL
   - `SUPABASE_ANON_KEY` = your anon public key
4. Click **Deploy**. You'll get a live URL like `https://oob-rewards.vercel.app`.

> If you ever rotate your Supabase key, just update the value in Vercel's
> Environment Variables and redeploy — no code change needed.

> Camera scanning (the staff QR scanner) **only works over HTTPS** — Vercel gives you HTTPS automatically, so it'll work there even though it won't on a plain local file.

---

## How customers use it

- Visit your live URL → **Join** → instant card with a QR code + 5% welcome code.
- On iPhone: Share → **Add to Home Screen**. On Android: menu → **Install app**. It then behaves like a native app.
- They show their QR at any venue to collect a stamp. At 6 stamps they pick a site and redeem £25 off.

## How staff use it

- Go to **your-url/#staff** (bookmark this on the desk tablet/phone).
- Enter the staff PIN.
- **Scan** the customer's QR (or type their `OOB-XXXXX` ref) → add a stamp, or apply the £25 reward.
- **Add a new customer** for walk-ins who don't have the app yet — gives them a ref on the spot.

**GDPR note:** when staff scan or look up a customer, they only ever see the anonymous reference (`OOB-XXXXX`) and the stamp count — never the name or email. Personal data stays locked in the database behind row-level security and is never sent to the staff device.

---

## Common questions

**"Can customers fake stamps?"** No — only a valid staff PIN can add a stamp, and every add is logged with the site and staff name.

**"What if someone loses their phone?"** Their card lives in the database against their email. They log in on any device and it's all there.

**"Can I change 6 stamps / £25 / 5%?"** Yes:
- The reward amount and 5% are display text in `index.html` (search for `£25` and `5%`).
- The number of stamps is `GOAL = 6` near the top of the script in `index.html`, and the `>= 6` / `- 6` checks in `supabase/schema.sql`. Change both to match.

**"Branded fonts?"** Headers use **Paytone One**, body uses **Inter**, per your house style. Buttons are yellow with white text and a press animation.
