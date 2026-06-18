-- ============================================================
--  OUT OF BOUNDS — LOYALTY SCHEME  ·  Supabase schema
--  Run this whole file in: Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================

-- ---------- EXTENSIONS ----------
create extension if not exists pgcrypto;

-- ============================================================
--  TABLES
-- ============================================================

-- Customers. The 'ref' is the only thing that ever goes in a QR code.
-- Personal data (name/email) lives here, protected by RLS so staff
-- never pull it during a scan.
create table if not exists public.customers (
  id            uuid primary key default gen_random_uuid(),
  auth_id       uuid unique references auth.users(id) on delete cascade,
  ref           text unique not null,          -- e.g. OOB-7F3K9  (goes in the QR)
  full_name     text not null,
  email         text not null,
  stamps        int  not null default 0,        -- current progress toward 6
  welcome_code  text,                            -- 5% off code issued at signup
  created_at    timestamptz not null default now()
);

-- Every stamp ever added (audit trail). Never decremented — redemptions
-- create a separate row. stamps column above is the live running balance.
create table if not exists public.stamp_events (
  id          uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  site        text not null check (site in ('levelup','axefactor','xscapenow')),
  staff_name  text,
  delta       int  not null default 1,          -- +1 for a stamp, -6 on a redemption
  kind        text not null default 'stamp' check (kind in ('stamp','redeem')),
  created_at  timestamptz not null default now()
);

-- £25 reward redemptions.
create table if not exists public.redemptions (
  id          uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  site        text not null check (site in ('levelup','axefactor','xscapenow')),
  amount      int  not null default 25,
  redeemed_at timestamptz not null default now()
);

-- Staff PIN(s). Hashed, never stored in plain text.
create table if not exists public.staff (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  pin_hash   text not null,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============================================================
--  HELPER: generate a unique customer ref like OOB-7F3K9
-- ============================================================
create or replace function public.gen_ref()
returns text language plpgsql as $$
declare
  alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- no confusing 0/O/1/I/L
  candidate text;
  i int;
begin
  loop
    candidate := 'OOB-';
    for i in 1..5 loop
      candidate := candidate || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.customers where ref = candidate);
  end loop;
  return candidate;
end $$;

-- ============================================================
--  ROW LEVEL SECURITY
-- ============================================================
alter table public.customers   enable row level security;
alter table public.stamp_events enable row level security;
alter table public.redemptions enable row level security;
alter table public.staff       enable row level security;

-- A logged-in customer can read & update ONLY their own row.
drop policy if exists "customer reads self" on public.customers;
create policy "customer reads self" on public.customers
  for select using (auth.uid() = auth_id);

drop policy if exists "customer inserts self" on public.customers;
create policy "customer inserts self" on public.customers
  for insert with check (auth.uid() = auth_id);

drop policy if exists "customer updates self" on public.customers;
create policy "customer updates self" on public.customers
  for update using (auth.uid() = auth_id);

-- A customer can read their own stamp history & redemptions.
drop policy if exists "customer reads own events" on public.stamp_events;
create policy "customer reads own events" on public.stamp_events
  for select using (
    customer_id in (select id from public.customers where auth_id = auth.uid())
  );

drop policy if exists "customer reads own redemptions" on public.redemptions;
create policy "customer reads own redemptions" on public.redemptions
  for select using (
    customer_id in (select id from public.customers where auth_id = auth.uid())
  );

-- Staff table and staff WRITE actions are NOT exposed to the client directly.
-- All staff actions go through SECURITY DEFINER functions below, which run
-- with elevated rights but require a valid PIN. This keeps customer PII out
-- of the staff client entirely.

-- ============================================================
--  STAFF RPCs  (called from the staff panel)
--  Each verifies a PIN before doing anything.
-- ============================================================

-- Verify a staff PIN, return the staff name if valid.
create or replace function public.staff_login(p_pin text)
returns table(staff_name text)
language plpgsql security definer set search_path = public as $$
begin
  return query
    select s.name from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash);
end $$;

-- Look up a customer by ref for the staff panel.
-- Returns ONLY ref + stamp balance — NO name, NO email. GDPR-safe scan.
create or replace function public.staff_lookup(p_pin text, p_ref text)
returns table(ref text, stamps int, ready boolean)
language plpgsql security definer set search_path = public as $$
declare ok boolean;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;

  return query
    select c.ref, c.stamps, (c.stamps >= 6) as ready
    from public.customers c where c.ref = p_ref;
end $$;

-- Add a stamp to a customer (by ref). Caps display at 6; refuses if already at 6.
create or replace function public.staff_add_stamp(p_pin text, p_ref text, p_site text, p_staff text)
returns table(ref text, stamps int, ready boolean)
language plpgsql security definer set search_path = public as $$
declare ok boolean; cust public.customers%rowtype;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;
  if p_site not in ('levelup','axefactor','xscapenow') then raise exception 'BAD_SITE'; end if;

  select * into cust from public.customers where ref = p_ref;
  if not found then raise exception 'NO_CUSTOMER'; end if;
  if cust.stamps >= 6 then raise exception 'CARD_FULL'; end if;

  update public.customers set stamps = stamps + 1 where id = cust.id;
  insert into public.stamp_events(customer_id, site, staff_name, delta, kind)
    values (cust.id, p_site, p_staff, 1, 'stamp');

  return query select c.ref, c.stamps, (c.stamps >= 6) as ready
    from public.customers c where c.id = cust.id;
end $$;

-- Process a £25 redemption (staff-side confirmation at the desk).
create or replace function public.staff_redeem(p_pin text, p_ref text, p_site text, p_staff text)
returns table(ref text, stamps int)
language plpgsql security definer set search_path = public as $$
declare ok boolean; cust public.customers%rowtype;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;
  if p_site not in ('levelup','axefactor','xscapenow') then raise exception 'BAD_SITE'; end if;

  select * into cust from public.customers where ref = p_ref;
  if not found then raise exception 'NO_CUSTOMER'; end if;
  if cust.stamps < 6 then raise exception 'NOT_READY'; end if;

  update public.customers set stamps = stamps - 6 where id = cust.id;
  insert into public.redemptions(customer_id, site) values (cust.id, p_site);
  insert into public.stamp_events(customer_id, site, staff_name, delta, kind)
    values (cust.id, p_site, p_staff, -6, 'redeem');

  return query select c.ref, c.stamps from public.customers c where c.id = cust.id;
end $$;

-- Staff add a brand-new customer at the desk (e.g. walk-ins with no smartphone).
-- Creates a customer with NO auth account; they can claim it later by ref+email.
create or replace function public.staff_add_customer(p_pin text, p_name text, p_email text)
returns table(ref text)
language plpgsql security definer set search_path = public as $$
declare ok boolean; new_ref text;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;

  new_ref := public.gen_ref();
  insert into public.customers(ref, full_name, email, welcome_code)
    values (new_ref, p_name, p_email, 'WELCOME5');
  return query select new_ref;
end $$;

-- Customer self-signup helper: links auth user, assigns ref + welcome code.
create or replace function public.claim_signup(p_name text, p_email text)
returns table(ref text, welcome_code text)
language plpgsql security definer set search_path = public as $$
declare new_ref text;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHED'; end if;
  -- already has a row?
  if exists(select 1 from public.customers where auth_id = auth.uid()) then
    return query select c.ref, c.welcome_code from public.customers c where c.auth_id = auth.uid();
    return;
  end if;
  new_ref := public.gen_ref();
  insert into public.customers(auth_id, ref, full_name, email, welcome_code)
    values (auth.uid(), new_ref, p_name, p_email, 'WELCOME5');
  return query select new_ref, 'WELCOME5';
end $$;

-- ============================================================
--  SEED A STAFF PIN  (change 1234 before going live!)
-- ============================================================
insert into public.staff(name, pin_hash)
  values ('Front Desk', crypt('1234', gen_salt('bf')))
on conflict do nothing;

-- To add more staff PINs later:
-- insert into public.staff(name, pin_hash) values ('Ash', crypt('5678', gen_salt('bf')));

-- ============================================================
--  DONE. Copy your Project URL + anon key into the app's config.
-- ============================================================
