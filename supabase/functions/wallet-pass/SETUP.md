# Apple & Google Wallet passes — Setup

Gives every customer a branded pass in Apple Wallet / Google Wallet that shows
their membership QR and live stamp count. Staff scan the QR off the pass with the
existing scanner — no new hardware.

Provider: **WalletWallet** (walletwallet.dev) — signs with their own certificate,
so no Apple Developer account needed. Free under 1,000 passes/month, then $19/month.

## Step 1 — WalletWallet account
1. Sign up at https://www.walletwallet.dev/signup/
2. Grab your API key (starts `ww_live_`).
3. (Optional) Use their live preview to tweak colours — though the pass content is
   already defined in the function (`passBody`), so you don't strictly need to.

## Step 2 — Database columns
Run `supabase/add_wallet_pass.sql` in the SQL Editor. It adds `pass_serial` and
`pass_share_url` to `customers` so we can update each pass later.

## Step 3 — Deploy the function
Either via the dashboard (Edge Functions → Create → name it `wallet-pass` → paste
`supabase/functions/wallet-pass/index.ts` → Deploy) or CLI:
```bash
supabase functions deploy wallet-pass --no-verify-jwt
```

## Step 4 — Secrets
The function needs three secrets (Edge Functions → Secrets, or CLI):
```bash
supabase secrets set WALLETWALLET_KEY=ww_live_your_key
supabase secrets set SB_URL=https://dvoddroxfkqxzzvzkivi.supabase.co
supabase secrets set SB_SERVICE_KEY=your_service_role_key
```
(The service-role key is in Project Settings → API → "service_role". It's a SECRET
key — it lives only in the function's secrets, never in the app or repo.)

## Step 5 — Auto-update passes when stamps change
Database → Webhooks → Create:
- Name: `wallet-sync`
- Table: `customers`
- Events: **Update**
- Type: Supabase Edge Functions → `wallet-pass`

Now every stamp add / redeem pushes the new count live to the customer's pass.

## Step 6 — Check the venue coordinates
Open `supabase/functions/wallet-pass/index.ts` and check the `LOCATIONS` array.
The two coordinates are approximate (Darwin Centre, Shrewsbury and Ketley Business
Park, Telford). For accurate lock-screen surfacing, replace them with the exact
lat/long of each venue (right-click the spot in Google Maps → copy coordinates).

## How customers use it
- On their rewards card they tap **Add to Apple / Google Wallet**.
- The pass lands in their wallet with the QR + stamp count.
- When they're near a venue, the card surfaces on their lock screen.
- Each stamp updates the count live with a celebratory notification.

## Notes
- Staff scanner is unchanged — the pass QR is the same `OOB-XXXXX` ref.
- The first time a customer taps "Add to Wallet", the pass is minted and the serial
  saved; after that the button links straight to their hosted pass page.
- Apple shows your custom stamp message on the lock screen; Google's banner is
  generic with the detail inside the pass (a WalletWallet platform difference).
