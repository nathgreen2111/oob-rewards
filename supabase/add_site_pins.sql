-- ============================================================
--  PER-SITE STAFF PINS
--  Run in Supabase SQL Editor. Adds a 'site' column to staff so
--  each location has its own PIN, and staff_login returns the site.
-- ============================================================

-- 1) add a site column to staff (nullable = works at any/all sites)
alter table public.staff add column if not exists site text
  check (site is null or site in ('levelup','axefactor','xscapenow'));

-- 2) update staff_login to also return the staff member's site
create or replace function public.staff_login(p_pin text)
returns table(staff_name text, staff_site text)
language plpgsql security definer set search_path = public, extensions as $staff_login$
begin
  return query select s.name, s.site from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash);
end $staff_login$;

-- 3) seed one PIN per site (CHANGE THESE before going live!)
--    Delete the old generic 'Front Desk' row first if you want only per-site PINs.
insert into public.staff(name, pin_hash, site) values
  ('LevelUp Desk',   crypt('1111', gen_salt('bf')), 'levelup'),
  ('Axe Factor Desk',crypt('2222', gen_salt('bf')), 'axefactor'),
  ('XscapeNow Desk',  crypt('3333', gen_salt('bf')), 'xscapenow')
on conflict do nothing;

-- To change a site PIN later:
-- update public.staff set pin_hash = crypt('NEW-PIN', gen_salt('bf')) where name = 'LevelUp Desk';
