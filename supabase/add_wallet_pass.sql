-- ============================================================
--  WALLET PASS support — stores each customer's pass identifiers
--  so we can update the pass live and show wallet buttons on return.
--  Run in Supabase SQL Editor.
-- ============================================================
alter table public.customers add column if not exists pass_serial text;
alter table public.customers add column if not exists pass_share_url text;
alter table public.customers add column if not exists pass_apple_url text;
alter table public.customers add column if not exists pass_google_url text;
