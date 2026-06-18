// Serves the public Supabase config to the browser from Vercel environment
// variables, so nothing sensitive is committed to the repo.
//
// Set these in Vercel → Project → Settings → Environment Variables.
// Accepts several common names so it works whichever you used:
//   SUPABASE_URL  or  NEXT_PUBLIC_SUPABASE_URL
//   SUPABASE_ANON_KEY  or  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY  or
//   SUPABASE_PUBLISHABLE_KEY  or  NEXT_PUBLIC_SUPABASE_ANON_KEY
//
// (The publishable / anon key is browser-safe by design — your database RLS +
//  PIN-protected functions are what enforce security. Env just keeps the repo clean.)

export default function handler(req, res) {
  const url =
    process.env.SUPABASE_URL ||
    process.env.NEXT_PUBLIC_SUPABASE_URL ||
    "";

  const key =
    process.env.SUPABASE_ANON_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
    "";

  res.setHeader("Content-Type", "application/javascript; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");

  res.status(200).send(
    `window.OOB_CONFIG = ${JSON.stringify({
      SUPABASE_URL: url,
      SUPABASE_ANON_KEY: key,
    })};`
  );
}
