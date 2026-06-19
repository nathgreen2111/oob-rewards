-- ============================================================
--  STAFF REPORTS — recent activity feed + today's summary.
--  Run in Supabase SQL Editor.
-- ============================================================

-- Recent activity (last N events), returns anonymous refs only.
create or replace function public.staff_recent(p_pin text, p_limit int default 8)
returns table(ref text, site text, kind text, staff_name text, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions as $staff_recent$
declare ok boolean;
begin
  select exists(select 1 from public.staff s where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;
  return query
    select c.ref, e.site, e.kind, e.staff_name, e.created_at
    from public.stamp_events e join public.customers c on c.id = e.customer_id
    order by e.created_at desc limit p_limit;
end $staff_recent$;

-- Today's totals (since midnight UTC): stamps, redemptions, by staff.
create or replace function public.staff_today(p_pin text)
returns table(staff_name text, site text, stamps_added bigint, redemptions bigint)
language plpgsql security definer set search_path = public, extensions as $staff_today$
declare ok boolean;
begin
  select exists(select 1 from public.staff s where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;
  return query
    select coalesce(e.staff_name,'—') as staff_name, e.site,
           count(*) filter (where e.kind='stamp') as stamps_added,
           count(*) filter (where e.kind='redeem') as redemptions
    from public.stamp_events e
    where e.created_at >= date_trunc('day', now())
    group by coalesce(e.staff_name,'—'), e.site
    order by stamps_added desc;
end $staff_today$;
