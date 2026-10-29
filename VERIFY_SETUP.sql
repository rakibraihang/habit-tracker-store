-- Run this after SUPABASE_SETUP_ALL_IN_ONE.sql succeeds.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'profiles','habits','habit_completions','journal_entries','planner_documents',
    'media_assets','shopping_list_items','products','cart_items','wishlist_items',
    'orders','order_items','user_app_state'
  )
order by table_name;

select id, name, public
from storage.buckets
where id in ('user-media','product-images')
order by id;

select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('profiles','habits','journal_entries','products','orders','user_app_state')
order by c.relname;
