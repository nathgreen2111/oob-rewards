-- ============================================================
--  OUT OF BOUNDS — LOYALTY SCHEME · Supabase schema (tested)
--  Run in: Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- TABLES ----------
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  auth_id uuid unique references auth.users(id) on delete cascade,
  ref text unique not null,
  full_name text not null,
  email text not null,
  stamps int not null default 0,
  welcome_code text,
  created_at timestamptz not null default now()
);

create table if not exists public.stamp_events (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  site text not null check (site in ('levelup','axefactor','xscapenow')),
  staff_name text,
  delta int not null default 1,
  kind text not null default 'stamp' check (kind in ('stamp','redeem')),
  created_at timestamptz not null default now()
);

create table if not exists public.redemptions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  site text not null check (site in ('levelup','axefactor','xscapenow')),
  amount int not null default 25,
  redeemed_at timestamptz not null default now()
);

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  pin_hash text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------- ROW LEVEL SECURITY ----------
alter table public.customers enable row level security;
alter table public.stamp_events enable row level security;
alter table public.redemptions enable row level security;
alter table public.staff enable row level security;

drop policy if exists "customer reads self" on public.customers;
create policy "customer reads self" on public.customers for select using (auth.uid() = auth_id);
drop policy if exists "customer inserts self" on public.customers;
create policy "customer inserts self" on public.customers for insert with check (auth.uid() = auth_id);
drop policy if exists "customer updates self" on public.customers;
create policy "customer updates self" on public.customers for update using (auth.uid() = auth_id);
drop policy if exists "customer reads own events" on public.stamp_events;
create policy "customer reads own events" on public.stamp_events for select using (
  customer_id in (select id from public.customers where auth_id = auth.uid())
);
drop policy if exists "customer reads own redemptions" on public.redemptions;
create policy "customer reads own redemptions" on public.redemptions for select using (
  customer_id in (select id from public.customers where auth_id = auth.uid())
);

-- ---------- FUNCTIONS (tested end-to-end) ----------
create or replace function public.staff_login(p_pin text)
returns table(staff_name text)
language plpgsql security definer set search_path = public, extensions as $staff_login$
begin
  return query select s.name from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash);
end $staff_login$;

create or replace function public.staff_lookup(p_pin text, p_ref text)
returns table(ref text, stamps int, ready boolean)
language plpgsql security definer set search_path = public, extensions as $staff_lookup$
declare ok boolean;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;
  return query select c.ref, c.stamps, (c.stamps >= 6) from public.customers c where c.ref = p_ref;
end $staff_lookup$;

create or replace function public.staff_add_stamp(p_pin text, p_ref text, p_site text, p_staff text)
returns table(ref text, stamps int, ready boolean)
language plpgsql security definer set search_path = public, extensions as $staff_add_stamp$
declare ok boolean; v_id uuid; v_stamps int;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;
  if p_site not in ('levelup','axefactor','xscapenow') then raise exception 'BAD_SITE'; end if;
  select c.id, c.stamps into v_id, v_stamps from public.customers c where c.ref = p_ref;
  if v_id is null then raise exception 'NO_CUSTOMER'; end if;
  if v_stamps >= 6 then raise exception 'CARD_FULL'; end if;
  update public.customers c set stamps = c.stamps + 1 where c.id = v_id;
  insert into public.stamp_events(customer_id, site, staff_name, delta, kind)
    values (v_id, p_site, p_staff, 1, 'stamp');
  return query select c.ref, c.stamps, (c.stamps >= 6) from public.customers c where c.id = v_id;
end $staff_add_stamp$;

create or replace function public.staff_redeem(p_pin text, p_ref text, p_site text, p_staff text)
returns table(ref text, stamps int)
language plpgsql security definer set search_path = public, extensions as $staff_redeem$
declare ok boolean; v_id uuid; v_stamps int;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;
  if p_site not in ('levelup','axefactor','xscapenow') then raise exception 'BAD_SITE'; end if;
  select c.id, c.stamps into v_id, v_stamps from public.customers c where c.ref = p_ref;
  if v_id is null then raise exception 'NO_CUSTOMER'; end if;
  if v_stamps < 6 then raise exception 'NOT_READY'; end if;
  update public.customers c set stamps = c.stamps - 6 where c.id = v_id;
  insert into public.redemptions(customer_id, site) values (v_id, p_site);
  insert into public.stamp_events(customer_id, site, staff_name, delta, kind)
    values (v_id, p_site, p_staff, -6, 'redeem');
  return query select c.ref, c.stamps from public.customers c where c.id = v_id;
end $staff_redeem$;

create or replace function public.staff_add_customer(p_pin text, p_name text, p_email text)
returns table(ref text)
language plpgsql security definer set search_path = public, extensions as $staff_add_customer$
declare ok boolean; new_ref text; alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;
  loop
    new_ref := 'OOB-';
    for i in 1..5 loop
      new_ref := new_ref || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.customers c where c.ref = new_ref);
  end loop;
  insert into public.customers(ref, full_name, email, welcome_code)
    values (new_ref, p_name, p_email, 'WELCOME5');
  return query select new_ref;
end $staff_add_customer$;

create or replace function public.claim_signup(p_name text, p_email text)
returns table(ref text, welcome_code text)
language plpgsql security definer set search_path = public, extensions as $claim_signup$
declare new_ref text; existing_ref text; existing_code text; alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHED'; end if;
  select c.ref, c.welcome_code into existing_ref, existing_code
    from public.customers c where c.auth_id = auth.uid();
  if existing_ref is not null then
    return query select existing_ref, existing_code; return;
  end if;
  loop
    new_ref := 'OOB-';
    for i in 1..5 loop
      new_ref := new_ref || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.customers c where c.ref = new_ref);
  end loop;
  insert into public.customers(auth_id, ref, full_name, email, welcome_code)
    values (auth.uid(), new_ref, p_name, p_email, 'WELCOME5');
  return query select new_ref, 'WELCOME5'::text;
end $claim_signup$;

-- ---------- SEED STAFF PIN (change 1234 before going live!) ----------
insert into public.staff(name, pin_hash)
  values ('Front Desk', crypt('1234', gen_salt('bf')))
on conflict do nothing;
