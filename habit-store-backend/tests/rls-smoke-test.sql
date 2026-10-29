-- Manual smoke-test checklist (run after creating two auth test users).
-- Do not run as a service_role/postgres session and assume that proves RLS works.
-- In Supabase SQL Editor, authenticated identity simulation can vary by setup;
-- preferably test through the browser client using two independent test accounts.

-- 1) Verify RLS is enabled on all exposed application tables:
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'profiles','habits','habit_completions','journal_entries','planner_documents',
    'media_assets','shopping_list_items','products','cart_items','wishlist_items','orders','order_items'
  )
order by tablename;

-- 2) Verify browser roles cannot call the privileged order RPC:
select has_function_privilege(
  'authenticated',
  'public.create_order_atomic(uuid,text,text,text,text,text,text,text,jsonb)',
  'execute'
) as authenticated_can_create_order; -- expected false

select has_function_privilege(
  'anon',
  'public.create_order_atomic(uuid,text,text,text,text,text,text,text,jsonb)',
  'execute'
) as anon_can_create_order; -- expected false

-- 3) Create two test users in Auth. Through the client, verify User A cannot
-- read/update/delete User B's habits, journal, planner, cart, wishlist or orders.
-- 4) Verify anonymous clients see published products only and cannot insert orders.
-- 5) Verify checkout refuses digital items until a payment provider is integrated.
