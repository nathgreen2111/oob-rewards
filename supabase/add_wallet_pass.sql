-- ============================================================
--  WALLET PASS support — adds a column to store each customer's
--  WalletWallet serial number so we can update their pass live.
--  Run in Supabase SQL Editor.
-- ============================================================
alter table public.customers add column if not exists pass_serial text;
alter table public.customers add column if not exists pass_share_url text;
