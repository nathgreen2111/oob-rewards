// Supabase Edge Function: wallet-pass
// Creates and updates Apple/Google Wallet passes via WalletWallet.
//
// Deploy:  supabase functions deploy wallet-pass --no-verify-jwt
// Secrets: supabase secrets set WALLETWALLET_KEY=ww_live_xxx
//          supabase secrets set SB_URL=https://YOURPROJECT.supabase.co
//          supabase secrets set SB_SERVICE_KEY=your_service_role_key
//
// Called two ways:
//   POST { action:"create", ref:"OOB-XXXXX" }   -> mints pass, returns shareUrl
//   POST { action:"sync",   ref:"OOB-XXXXX" }   -> pushes current stamp count live
//
// Also safe to call from a Database Webhook on customers UPDATE (auto-sync stamps).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const WW_KEY = Deno.env.get("WALLETWALLET_KEY")!;
const SB_URL = Deno.env.get("SB_URL")!;
const SB_SERVICE_KEY = Deno.env.get("SB_SERVICE_KEY")!;
const WW_BASE = "https://api.walletwallet.dev";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Your three venues for lock-screen geofencing
const LOCATIONS = [
  { latitude: 52.7080, longitude: -2.7536, relevantText: "Welcome to LevelUp Escapes / The Axe Factor!" }, // Darwin Centre, Shrewsbury SY1 1BW
  { latitude: 52.6934, longitude: -2.4824, relevantText: "Welcome to XscapeNow!" },                          // Ketley Business Park, Telford TF1 5JD
];

// Build the FULL pass body (PUT replaces everything, so always send all fields).
function passBody(c: { ref: string; full_name: string; stamps: number }) {
  const first = (c.full_name || "Member").split(" ")[0];
  const ready = c.stamps >= 6;
  return {
    barcodeValue: c.ref,
    barcodeFormat: "QR",
    logoText: "",
    organizationName: "Out of Bounds Rewards",
    description: "Out of Bounds Rewards loyalty card",
    headerFields: [{
      label: "STAMPS",
      value: ready ? "READY 🎉" : `${c.stamps} / 6`,
      changeMessage: ready ? "Your £25 reward is ready! 🎉" : "You're at %@ stamps — keep going!"
    }],
    primaryFields: [{ label: "MEMBER", value: first }],
    secondaryFields: [
      { label: "REWARD", value: ready ? "£25 ready to claim" : "£25 off at 6 stamps" },
      { label: "MEMBERSHIP No.", value: c.ref }
    ],
    backFields: [
      { label: "How it works", value: "Collect 6 stamps across LevelUp Escapes, The Axe Factor and XscapeNow to earn £25 off." },
      { label: "LevelUp Escapes", value: "Unit SU33, Darwin Centre, Shrewsbury SY1 1BW · help@levelupescapes.com" },
      { label: "The Axe Factor", value: "Unit SU33, Darwin Centre, Shrewsbury SY1 1BW · axeperts@theaxefactor.co.uk" },
      { label: "XscapeNow", value: "Units 17–19, Ketley Business Park, Telford TF1 5JD · info@xscapenow.co.uk" }
    ],
    locations: LOCATIONS,
    color: "#E64362",
    colorPreset: "red",
    logoURL: "https://oob-rewards.vercel.app/logos/outofbounds.png",
    sharingProhibited: true
  };
}

async function sbFetch(path: string, opts: RequestInit = {}) {
  return fetch(`${SB_URL}/rest/v1/${path}`, {
    ...opts,
    headers: {
      "apikey": SB_SERVICE_KEY,
      "Authorization": `Bearer ${SB_SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(opts.headers || {})
    }
  });
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }
  try {
    const payload = await req.json();
    // Accept either a direct call { action, ref } or a DB webhook { type, record }.
    let action = payload.action;
    let ref = payload.ref;
    if (!ref && payload.record) {
      ref = payload.record.ref;
      // On a customers UPDATE webhook, sync the pass if one exists, else skip.
      action = payload.record.pass_serial ? "sync" : "skip";
    }
    if (action === "skip") return new Response("no pass yet", { status: 200, headers: CORS });
    if (!ref) return new Response("missing ref", { status: 400, headers: CORS });

    // load the customer
    const r = await sbFetch(`customers?ref=eq.${encodeURIComponent(ref)}&select=ref,full_name,stamps,pass_serial`);
    const rows = await r.json();
    const cust = rows[0];
    if (!cust) return new Response("no customer", { status: 404, headers: CORS });

    if (action === "create" || !cust.pass_serial) {
      // mint a new pass
      const res = await fetch(`${WW_BASE}/api/passes`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${WW_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify(passBody(cust))
      });
      if (!res.ok) { console.error("WW create failed", await res.text()); return new Response("ww error", { status: 502, headers: CORS }); }
      const data = await res.json();
      // store serial + share url
      await sbFetch(`customers?ref=eq.${encodeURIComponent(ref)}`, {
        method: "PATCH",
        body: JSON.stringify({ pass_serial: data.serialNumber, pass_share_url: data.shareUrl })
      });
      return Response.json({ shareUrl: data.shareUrl, googleSaveUrl: data.googleSaveUrl, serial: data.serialNumber }, { headers: CORS });
    } else {
      // sync existing pass (full body)
      const res = await fetch(`${WW_BASE}/api/passes/${cust.pass_serial}`, {
        method: "PUT",
        headers: { "Authorization": `Bearer ${WW_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify(passBody(cust))
      });
      if (!res.ok) { console.error("WW update failed", await res.text()); return new Response("ww error", { status: 502, headers: CORS }); }
      return Response.json({ ok: true }, { headers: CORS });
    }
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500, headers: CORS });
  }
});
