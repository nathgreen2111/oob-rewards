// Serves the public Supabase config to the browser from Vercel environment
// variables, so nothing sensitive is committed to the repo.
//
// Set these in Vercel → Project → Settings → Environment Variables:
//   SUPABASE_URL        = https://YOUR-PROJECT.supabase.co
//   SUPABASE_ANON_KEY   = your anon public key
//
// (The anon key is browser-safe by design — your database RLS + PIN-protected
//  functions are what enforce security. Keeping it in env just keeps the repo clean.)

export default function handler(req, res) {
  const url = process.env.SUPABASE_URL || "";
  const anon = process.env.SUPABASE_ANON_KEY || "";

  res.setHeader("Content-Type", "application/javascript; charset=utf-8");
  // don't cache, so rotating the key takes effect immediately
  res.setHeader("Cache-Control", "no-store");

  res.status(200).send(
    `window.OOB_CONFIG = ${JSON.stringify({
      SUPABASE_URL: url,
      SUPABASE_ANON_KEY: anon,
    })};`
  );
}
