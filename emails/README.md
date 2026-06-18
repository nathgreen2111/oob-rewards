# Branded Email Templates — Setup

Four branded HTML emails for your Supabase auth flows, matching the rewards app
(navy, Out of Bounds logo, yellow buttons, teal highlights).

| File | Use in Supabase template |
|------|---------------------------|
| `01_confirm_signup.html` | **Confirm signup** |
| `02_magic_link.html`     | **Magic Link** |
| `03_reset_password.html` | **Reset Password** |
| `04_change_email.html`   | **Change Email Address** |

## Before you install — two required edits

### 1. Set your real site URL (fixes the localhost problem)
In Supabase → **Authentication → URL Configuration**:
- **Site URL**: `https://your-app.vercel.app`  (your real Vercel domain)
- **Redirect URLs**: add `https://your-app.vercel.app/**`

This is what makes the email links point to your live site instead of localhost.

### 2. Fix the logo URL in each template
Each file references the logo at:
```
https://YOUR-APP.vercel.app/logos/outofbounds.png
```
Find/replace `YOUR-APP.vercel.app` with your real Vercel domain in all four files
before pasting. (Email clients can only load images from a public HTTPS URL —
they can't read files from your repo, so the logo must be served by your live site.)

## Installing each template

1. Supabase → **Authentication → Email Templates**.
2. Pick a template from the dropdown (e.g. "Confirm signup").
3. Open the matching `.html` file, copy **all** of it.
4. Paste into the template's HTML box (replace what's there).
5. Optionally set the **Subject** lines:
   - Confirm signup: `Confirm your email — Out of Bounds Rewards`
   - Magic Link: `Your login link — Out of Bounds Rewards`
   - Reset Password: `Reset your password — Out of Bounds Rewards`
   - Change Email: `Confirm your new email — Out of Bounds Rewards`
6. Save. Repeat for all four.

## Confirm-email flow note

You chose to keep email confirmation **on**, so make sure in
**Authentication → Providers → Email** that "Confirm email" is **ON**.
New customers will get the branded "Confirm signup" email and must tap the link
before their card activates. The app already handles this — it shows a
"Check your email" screen after signup.

## A note on Supabase's built-in email limits

Supabase's default email service is rate-limited (a few per hour) and meant for
testing. Once you're live and getting real signups, set up a custom SMTP provider
(Authentication → Settings → SMTP) — e.g. Resend, SendGrid, or your existing
business email host — so emails always send and land in inboxes rather than spam.
