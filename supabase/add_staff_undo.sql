-- ============================================================
--  STAFF UNDO — reverse the most recent stamp or redemption for a
--  customer (used by the "Undo" button within ~60s of an action).
--  Run in Supabase SQL Editor.
-- ============================================================
create or replace function public.staff_undo(p_pin text, p_ref text)
returns table(ref text, stamps int, ready boolean)
language plpgsql security definer set search_path = public, extensions as $staff_undo$
declare ok boolean; v_id uuid; last_kind text; last_id uuid;
begin
  select exists(select 1 from public.staff s
    where s.active and s.pin_hash = crypt(p_pin, s.pin_hash)) into ok;
  if not ok then raise exception 'INVALID_PIN'; end if;

  select c.id into v_id from public.customers c where c.ref = p_ref;
  if v_id is null then raise exception 'NO_CUSTOMER'; end if;

  -- find the most recent event for this customer
  select e.id, e.kind into last_id, last_kind
    from public.stamp_events e
    where e.customer_id = v_id
    order by e.created_at desc limit 1;
  if last_id is null then raise exception 'NOTHING_TO_UNDO'; end if;

  if last_kind = 'stamp' then
    update public.customers c set stamps = greatest(0, c.stamps - 1) where c.id = v_id;
    delete from public.stamp_events where id = last_id;
  else -- redeem: restore the 6 stamps and remove the redemption
    update public.customers c set stamps = c.stamps + 6 where c.id = v_id;
    delete from public.stamp_events where id = last_id;
    delete from public.redemptions r where r.id = (
      select id from public.redemptions where customer_id = v_id order by redeemed_at desc limit 1
    );
  end if;

  return query select c.ref, c.stamps, (c.stamps >= 6) from public.customers c where c.id = v_id;
end $staff_undo$;
