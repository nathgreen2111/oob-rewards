// Supabase Edge Function: send-email
// Sends branded transactional emails (welcome + reward) via Resend.
//
// Deploy:  supabase functions deploy send-email --no-verify-jwt
// Secret:  supabase secrets set RESEND_API_KEY=re_your_key
//
// Triggered by Database Webhooks. Receives the changed `customers` row
// and decides which email (if any) to send.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const FROM = "Out of Bounds Rewards <rewards@outofboundstraining.co.uk>";

const WELCOME_HTML = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="x-apple-disable-message-reformatting"><title>Welcome to Out of Bounds Rewards</title></head>
<body style="margin:0;padding:0;background:#12132a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">Your 5% welcome code is inside — plus how to earn £25 off.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#12132a;padding:32px 16px;"><tr><td align="center">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#20233f;border-radius:18px;overflow:hidden;border:1px solid rgba(255,255,255,0.08);">
    <tr><td style="background:linear-gradient(135deg,#E64362 0%,#CF3C56 100%);padding:28px 32px;text-align:center;">
      <img src="https://oob-rewards.vercel.app/logos/outofbounds.png" alt="Out of Bounds Immersive" width="190" style="max-width:190px;height:auto;display:inline-block;"></td></tr>
    <tr><td style="padding:36px 32px 8px 32px;">
      <h1 style="margin:0 0 16px 0;color:#ffffff;font-size:24px;font-weight:800;line-height:1.25;">Welcome, {{name}}! 🎉</h1>
      <div style="color:#c7cbe6;font-size:15px;line-height:1.65;"><p style='margin:0 0 14px 0;'>Your <strong style='color:#fff;'>Out of Bounds Rewards</strong> card is live. Collect <strong>6 stamps</strong> across LevelUp Escapes, The Axe Factor and XscapeNow and you'll earn <strong style='color:#43C4B2;'>£25 off</strong>.</p><p style='margin:0 0 18px 0;'>As a thank you for joining, here's <strong style='color:#43C4B2;'>5% off your next booking</strong>:</p><div style='background:#171933;border:1px dashed #43C4B2;border-radius:12px;padding:16px;text-align:center;'><div style='font-size:12px;color:#9aa0c0;letter-spacing:1px;'>YOUR CODE</div><div style='font-family:Georgia,serif;font-size:26px;font-weight:800;color:#43C4B2;letter-spacing:3px;margin-top:4px;'>WELCOME5</div></div><p style='margin:18px 0 0 0;font-size:13px;color:#9aa0c0;'>Just show your card's QR code at any of our venues to start collecting stamps.</p></div></td></tr>
    <tr><td style="padding:24px 32px 8px 32px;" align="center">
      <table role="presentation" cellpadding="0" cellspacing="0"><tr><td align="center" style="border-radius:14px;background:#FFD23F;">
        <a href="https://oob-rewards.vercel.app" target="_blank" style="display:inline-block;padding:15px 38px;font-size:16px;font-weight:800;color:#ffffff;text-decoration:none;border-radius:14px;text-shadow:0 1px 0 rgba(0,0,0,0.25);">Open my rewards card</a>
      </td></tr></table></td></tr>
    <tr><td style="padding:22px 32px;background:#1a1c34;border-top:1px solid rgba(255,255,255,0.06);text-align:center;">
      <p style="margin:0 0 6px 0;color:#9aa0c0;font-size:12px;font-weight:600;letter-spacing:0.5px;">OUT OF BOUNDS REWARDS</p>
      <p style="margin:0;color:#6b7099;font-size:11px;line-height:1.6;">LevelUp Escapes &nbsp;·&nbsp; The Axe Factor &nbsp;·&nbsp; XscapeNow</p></td></tr>
  </table>
  <p style="color:#494d70;font-size:11px;margin:18px 0 0 0;">© Out of Bounds Immersive Experiences Ltd</p>
</td></tr></table></body></html>`;
const REWARD_HTML = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="x-apple-disable-message-reformatting"><title>You've unlocked £25 off!</title></head>
<body style="margin:0;padding:0;background:#12132a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">6 stamps complete — your £25 reward is ready to claim.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#12132a;padding:32px 16px;"><tr><td align="center">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#20233f;border-radius:18px;overflow:hidden;border:1px solid rgba(255,255,255,0.08);">
    <tr><td style="background:linear-gradient(135deg,#43C4B2 0%,#35a99a 100%);padding:28px 32px;text-align:center;">
      <img src="https://oob-rewards.vercel.app/logos/outofbounds.png" alt="Out of Bounds Immersive" width="190" style="max-width:190px;height:auto;display:inline-block;"></td></tr>
    <tr><td style="padding:36px 32px 8px 32px;">
      <h1 style="margin:0 0 16px 0;color:#ffffff;font-size:24px;font-weight:800;line-height:1.25;">You did it — £25 off unlocked! 🎉</h1>
      <div style="color:#c7cbe6;font-size:15px;line-height:1.65;"><p style='margin:0 0 14px 0;'>Brilliant, {{name}} — you've collected all <strong>6 stamps</strong>. Your <strong style='color:#43C4B2;'>£25 reward</strong> is ready.</p><p style='margin:0 0 14px 0;'>Open your rewards card, choose the venue you'd like to use it at, and email them quoting your membership number to claim. They'll verify and apply your £25 off.</p><p style='margin:0;font-size:13px;color:#9aa0c0;'>Your membership number is shown on your card.</p></div></td></tr>
    <tr><td style="padding:24px 32px 8px 32px;" align="center">
      <table role="presentation" cellpadding="0" cellspacing="0"><tr><td align="center" style="border-radius:14px;background:#FFD23F;">
        <a href="https://oob-rewards.vercel.app" target="_blank" style="display:inline-block;padding:15px 38px;font-size:16px;font-weight:800;color:#ffffff;text-decoration:none;border-radius:14px;text-shadow:0 1px 0 rgba(0,0,0,0.25);">Claim my £25 reward</a>
      </td></tr></table></td></tr>
    <tr><td style="padding:22px 32px;background:#1a1c34;border-top:1px solid rgba(255,255,255,0.06);text-align:center;">
      <p style="margin:0 0 6px 0;color:#9aa0c0;font-size:12px;font-weight:600;letter-spacing:0.5px;">OUT OF BOUNDS REWARDS</p>
      <p style="margin:0;color:#6b7099;font-size:11px;line-height:1.6;">LevelUp Escapes &nbsp;·&nbsp; The Axe Factor &nbsp;·&nbsp; XscapeNow</p></td></tr>
  </table>
  <p style="color:#494d70;font-size:11px;margin:18px 0 0 0;">© Out of Bounds Immersive Experiences Ltd</p>
</td></tr></table></body></html>`;

function fill(tpl: string, vars: Record<string,string>) {
  return tpl.replace(/{{(\w+)}}/g, (_, k) => vars[k] ?? "");
}

async function sendEmail(to: string, subject: string, html: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": "Bearer " + RESEND_API_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to, subject, html }),
  });
  if (!res.ok) console.error("Resend error:", await res.text());
  return res.ok;
}

serve(async (req) => {
  try {
    const payload = await req.json();
    const rec = payload.record || {};
    const old = payload.old_record || {};
    const type = payload.type; // INSERT | UPDATE
    const firstName = (rec.full_name || "there").split(" ")[0];

    // 1) WELCOME — new customer row with an email
    if (type === "INSERT" && rec.email) {
      await sendEmail(rec.email, "Welcome to Out of Bounds Rewards", fill(WELCOME_HTML, { name: firstName }));
      return new Response("welcome sent", { status: 200 });
    }

    // 2) REWARD — stamps cross from below 6 up to 6
    if (type === "UPDATE" && rec.email && (old.stamps ?? 0) < 6 && (rec.stamps ?? 0) >= 6) {
      await sendEmail(rec.email, "You've unlocked £25 off!", fill(REWARD_HTML, { name: firstName }));
      return new Response("reward sent", { status: 200 });
    }

    return new Response("no email needed", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500 });
  }
});
