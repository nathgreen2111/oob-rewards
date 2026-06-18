# Welcome & Reward emails (transactional)

These two are different from the auth emails (confirm/reset/etc). They're
"transactional" emails your system sends when something happens:

- `05_welcome.html` — send once, when a customer first signs up (includes WELCOME5)
- `06_reward_unlocked.html` — send when a customer reaches 6 stamps

Both use `{{name}}` as a placeholder — replace with the customer's first name when sending.

## Important: WELCOME5 once per email
You asked that WELCOME5 only be usable once per customer. That's enforced at the
booking/checkout side, not here — when someone redeems WELCOME5 in your booking
system, mark it used against their email so it can't be reused. The email just
delivers the code.

## How to actually send them — two options

### Option A — Simplest: send manually / semi-automated (start here)
For low volume at launch, you can send the welcome email from Resend's dashboard
or a simple scheduled check. Practical and zero engineering. Fine until you have
steady signups.

### Option B — Automated via Supabase Edge Function + Resend (proper long-term)
A small serverless function on Supabase fires these automatically:
- Welcome: triggered by a new row in `customers` (database webhook → function → Resend API)
- Reward: triggered when `stamps` reaches 6

This needs an Edge Function written and deployed with your Resend API key stored
as a Supabase secret. It's the right end-state but more setup. When you're ready,
this can be built as a focused next step — it's self-contained.

## Sending through Resend
Since your domain (outofboundstraining.co.uk) is already verified in Resend, these
will send from `rewards@outofboundstraining.co.uk` and land in inboxes, exactly
like the confirm email already does.
