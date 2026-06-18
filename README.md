# Out of Bounds Rewards

Cross-brand digital loyalty scheme for **LevelUp Escapes**, **The Axe Factor** and **XscapeNow**.

- **6 stamps → £25 off** (collected at any site, redeemed at one)
- **5% off** for signing up
- Anonymous QR codes — GDPR-safe staff scanning
- Progressive Web App (add to home screen, no app store)
- Supabase backend, deploys to GitHub + Vercel
- Supabase keys load from Vercel environment variables — nothing sensitive in the repo

## Quick start

See **[SETUP.md](SETUP.md)** for full step-by-step instructions (~20 min, no coding).

In short:
1. Create a free Supabase project, run `supabase/schema.sql`.
2. Push to GitHub, import into Vercel.
3. Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` as Vercel environment variables, deploy.

## Structure

```
loyalty/
├─ index.html          <- the whole app (customer + staff panels)
├─ manifest.json       <- PWA / add-to-home-screen
├─ logos/              <- brand logos + generated app icon
├─ api/
│  └─ config.js        <- serves Supabase keys from Vercel env vars
├─ supabase/
│  └─ schema.sql       <- run once in Supabase SQL editor
├─ vercel.json
└─ SETUP.md
```

## Staff access

Visit `your-url/#staff` and enter the staff PIN.
# oob-rewards
