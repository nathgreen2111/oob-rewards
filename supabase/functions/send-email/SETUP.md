# Automated Welcome & Reward Emails — Setup

This makes the welcome email (on signup) and reward email (at 6 stamps) send
automatically through Resend. It's a Supabase Edge Function plus two database
webhooks.

You'll need the Supabase CLI for the deploy step (one-time install):
https://supabase.com/docs/guides/cli

## Step 1 — Deploy the function

From the project root:

```bash
supabase login
supabase link --project-ref dvoddroxfkqxzzvzkivi
supabase functions deploy send-email --no-verify-jwt
```

## Step 2 — Give it your Resend key

```bash
supabase secrets set RESEND_API_KEY=re_your_resend_key_here
```

(Same Resend API key you used for SMTP. The function uses it to send via Resend's API.)

## Step 3 — Wire the database webhooks

In the Supabase dashboard: **Database → Webhooks → Create a new hook**.

**Webhook 1 — Welcome on signup**
- Name: `welcome-email`
- Table: `customers`
- Events: tick **Insert**
- Type: **Supabase Edge Functions** → select `send-email`
- Create.

**Webhook 2 — Reward at 6 stamps**
- Name: `reward-email`
- Table: `customers`
- Events: tick **Update**
- Type: **Supabase Edge Functions** → select `send-email`
- Create.

That's it. The function itself checks the data and only sends:
- a **welcome** email when a new customer row is created with an email
- a **reward** email when a customer's stamps go from below 6 up to 6

It won't double-send: ordinary stamp adds (e.g. 4→5) send nothing, and it only
fires the reward on the exact crossing to 6.

## Step 4 — Test

- Sign up a new customer → welcome email arrives.
- Add stamps until they hit 6 → reward email arrives.

Watch **Resend → Emails** to confirm delivery, and **Supabase → Edge Functions →
send-email → Logs** if anything doesn't fire.

## Notes

- Emails send from `rewards@outofboundstraining.co.uk` (your verified domain), so
  they land in inboxes like the confirm email already does.
- WELCOME5 "once per customer" is still enforced at your booking checkout, not here.
- Walk-in customers added by staff (who provide an email) will also get a welcome
  email automatically, since that also creates a customers row.
