-- Habit Tracker + Store: consolidated Supabase setup script
-- Project: rkgweeatovvkeyxnjamv
-- Run once in Supabase Dashboard > SQL Editor after reviewing this file.
-- Creates schema, RLS policies, storage buckets and private per-user app backup.
-- Does NOT deploy the create-order Edge Function or connect the store UI.
-- Stop and inspect any SQL error before proceeding.


-- ============================================================
-- SOURCE MIGRATION: 202610290001_initial_schema.sql
-- ============================================================
-- Habit Tracker + Store starter schema for Supabase PostgreSQL
-- Review and run in Supabase SQL Editor only after creating your project.
-- This file intentionally does NOT create an admin user or expose service-role credentials.

create extension if not exists pgcrypto;

-- Profiles are created automatically for authenticated users.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'user' check (role in ('user','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  sort_order integer not null default 0,
  color text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists habits_user_sort_idx on public.habits(user_id, sort_order);

create table if not exists public.habit_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  habit_id uuid not null references public.habits(id) on delete cascade,
  completed_on date not null,
  created_at timestamptz not null default now(),
  unique (habit_id, completed_on)
);
create index if not exists habit_completions_user_date_idx on public.habit_completions(user_id, completed_on desc);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  mood text not null default '' check (char_length(mood) <= 32),
  body text not null default '' check (char_length(body) <= 10000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, entry_date)
);

-- Preserve the existing app's monthly and weekly planner notes without flattening them.
create table if not exists public.planner_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  period_type text not null check (period_type in ('weekly','monthly','reflection')),
  period_key text not null check (char_length(period_key) between 1 and 20),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, period_type, period_key)
);

create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  media_type text not null check (media_type in ('image','video')),
  title text not null default '' check (char_length(title) <= 200),
  storage_path text not null,
  created_at timestamptz not null default now(),
  unique (user_id, storage_path)
);

create table if not exists public.shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  quantity integer not null default 1 check (quantity between 1 and 10000),
  unit_price numeric(12,2) not null default 0 check (unit_price >= 0),
  is_bought boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Store catalog. Only published products are readable by anonymous visitors.
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null check (char_length(trim(name)) between 1 and 200),
  description text not null default '',
  category text not null default 'general',
  product_type text not null default 'physical' check (product_type in ('physical','digital')),
  price numeric(12,2) not null check (price >= 0),
  currency char(3) not null default 'BDT',
  stock_quantity integer check (stock_quantity is null or stock_quantity >= 0),
  image_path text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists products_published_category_idx on public.products(is_published, category);

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity integer not null default 1 check (quantity between 1 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, product_id)
);

create table if not exists public.wishlist_items (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

-- Orders must be created by a trusted server/Edge Function, not directly by the browser.
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  user_id uuid references auth.users(id) on delete set null,
  customer_name text not null check (char_length(trim(customer_name)) between 2 and 120),
  customer_phone text not null check (char_length(trim(customer_phone)) between 8 and 30),
  customer_email text,
  shipping_address text,
  shipping_area text,
  customer_note text not null default '',
  currency char(3) not null default 'BDT',
  subtotal numeric(12,2) not null check (subtotal >= 0),
  delivery_fee numeric(12,2) not null default 0 check (delivery_fee >= 0),
  total numeric(12,2) not null check (total >= 0),
  payment_method text not null default 'cod' check (payment_method in ('cod','bkash','nagad','rocket','card','other')),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','pending','paid','failed','refunded','partially_refunded')),
  order_status text not null default 'pending' check (order_status in ('pending','confirmed','processing','shipped','delivered','cancelled','returned')),
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists orders_user_created_idx on public.orders(user_id, created_at desc);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name_snapshot text not null,
  product_slug_snapshot text not null default '',
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity between 1 and 1000),
  line_total numeric(12,2) not null check (line_total >= 0),
  created_at timestamptz not null default now()
);
create index if not exists order_items_order_idx on public.order_items(order_id);

-- Enable RLS on every exposed table.
alter table public.profiles enable row level security;
alter table public.habits enable row level security;
alter table public.habit_completions enable row level security;
alter table public.journal_entries enable row level security;
alter table public.planner_documents enable row level security;
alter table public.media_assets enable row level security;
alter table public.shopping_list_items enable row level security;
alter table public.products enable row level security;
alter table public.cart_items enable row level security;
alter table public.wishlist_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Profiles: user can read/update own non-role fields. No client role updates allowed.
drop policy if exists "profile read own" on public.profiles;
create policy "profile read own" on public.profiles for select to authenticated using (id = (select auth.uid()));
drop policy if exists "profile update own non-role" on public.profiles;
create policy "profile update own non-role" on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke update (role, id) on public.profiles from authenticated, anon;

-- User-owned personal data: every row must belong to the current authenticated user.
drop policy if exists "habits own select" on public.habits;
create policy "habits own select" on public.habits for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "habits own insert" on public.habits;
create policy "habits own insert" on public.habits for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "habits own update" on public.habits;
create policy "habits own update" on public.habits for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists "habits own delete" on public.habits;
create policy "habits own delete" on public.habits for delete to authenticated using (user_id = (select auth.uid()));

-- A completion must belong to a habit owned by the same user.
drop policy if exists "completions own select" on public.habit_completions;
create policy "completions own select" on public.habit_completions for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "completions own insert" on public.habit_completions;
create policy "completions own insert" on public.habit_completions for insert to authenticated with check (user_id = (select auth.uid()) and exists (select 1 from public.habits h where h.id = habit_id and h.user_id = (select auth.uid())));
drop policy if exists "completions own update" on public.habit_completions;
create policy "completions own update" on public.habit_completions for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and exists (select 1 from public.habits h where h.id = habit_id and h.user_id = (select auth.uid())));
drop policy if exists "completions own delete" on public.habit_completions;
create policy "completions own delete" on public.habit_completions for delete to authenticated using (user_id = (select auth.uid()));

-- Journal, planner, media, and shopping-list rows.
do $$
declare t text;
begin
  foreach t in array array['journal_entries','planner_documents','media_assets','shopping_list_items'] loop
    execute format('drop policy if exists %I on public.%I', t || ' own select', t);
    execute format('create policy %I on public.%I for select to authenticated using (user_id = (select auth.uid()))', t || ' own select', t);
    execute format('drop policy if exists %I on public.%I', t || ' own insert', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t || ' own insert', t);
    execute format('drop policy if exists %I on public.%I', t || ' own update', t);
    execute format('create policy %I on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t || ' own update', t);
    execute format('drop policy if exists %I on public.%I', t || ' own delete', t);
    execute format('create policy %I on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t || ' own delete', t);
  end loop;
end $$;

-- Products: public can only read published products; authenticated admin can manage catalog.
drop policy if exists "published products public read" on public.products;
create policy "published products public read" on public.products for select to anon, authenticated using (is_published = true or exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists "admin products insert" on public.products;
create policy "admin products insert" on public.products for insert to authenticated with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists "admin products update" on public.products;
create policy "admin products update" on public.products for update to authenticated using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin')) with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists "admin products delete" on public.products;
create policy "admin products delete" on public.products for delete to authenticated using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));

-- Cart and wishlist are per-user.
do $$
declare t text;
begin
  foreach t in array array['cart_items','wishlist_items'] loop
    execute format('drop policy if exists %I on public.%I', t || ' own select', t);
    execute format('create policy %I on public.%I for select to authenticated using (user_id = (select auth.uid()))', t || ' own select', t);
    execute format('drop policy if exists %I on public.%I', t || ' own insert', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t || ' own insert', t);
    execute format('drop policy if exists %I on public.%I', t || ' own update', t);
    execute format('create policy %I on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t || ' own update', t);
    execute format('drop policy if exists %I on public.%I', t || ' own delete', t);
    execute format('create policy %I on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t || ' own delete', t);
  end loop;
end $$;

-- Orders: client may read only own orders. No browser-side insert/update/delete policies.
drop policy if exists "users read own orders" on public.orders;
create policy "users read own orders" on public.orders for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "users read own order items" on public.order_items;
create policy "users read own order items" on public.order_items for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id and o.user_id = (select auth.uid())));
-- Order creation, payment verification, stock decrement and admin status changes must happen in a trusted Edge Function/server.

-- Restrict table access to intended roles; RLS policies still apply.
grant select, insert, update, delete on public.habits, public.habit_completions,
  public.journal_entries, public.planner_documents, public.media_assets,
  public.shopping_list_items, public.cart_items, public.wishlist_items to authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, updated_at) on public.profiles to authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.orders, public.order_items to authenticated;

-- Note: set profile role='admin' manually using trusted SQL after verifying the account.
-- Never expose the Supabase service_role key in the HTML/browser.


-- ============================================================
-- SOURCE MIGRATION: 202610290002_atomic_order_creation.sql
-- ============================================================
-- Atomic, server-only order creation for authenticated customers.
-- Digital orders are intentionally blocked until a payment provider is integrated
-- and server-side payment verification is implemented.

create or replace function public.create_order_atomic(
  p_user_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_customer_email text,
  p_shipping_address text,
  p_shipping_area text,
  p_customer_note text,
  p_payment_method text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order_id uuid := gen_random_uuid();
  v_order_number text;
  v_subtotal numeric(12,2) := 0;
  v_delivery_fee numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
  v_has_physical boolean := false;
  v_has_digital boolean := false;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_line numeric(12,2);
begin
  if p_user_id is null
     or char_length(trim(coalesce(p_customer_name, ''))) not between 2 and 120
     or char_length(regexp_replace(coalesce(p_customer_phone, ''), '\D', '', 'g')) < 8
     or coalesce(jsonb_typeof(p_items), 'null') <> 'array'
     or coalesce(jsonb_array_length(p_items), 0) < 1
     or coalesce(jsonb_array_length(p_items), 0) > 50 then
    raise exception 'INVALID_ITEMS';
  end if;

  if coalesce(p_payment_method, '') <> 'cod' then
    raise exception 'PAYMENT_METHOD_UNAVAILABLE';
  end if;

  -- Reject repeated product IDs to keep quantity and stock logic unambiguous.
  if exists (
    select 1
    from jsonb_array_elements(p_items) as x(item)
    group by x.item ->> 'product_id'
    having count(*) > 1
  ) then
    raise exception 'INVALID_ITEMS';
  end if;

  -- Lock product rows in stable UUID order, preventing concurrent overselling.
  for v_item in
    select x.item
    from jsonb_array_elements(p_items) as x(item)
    order by (x.item ->> 'product_id')
  loop
    if coalesce(v_item ->> 'product_id', '') !~* '^[0-9a-f-]{36}$'
       or coalesce(v_item ->> 'quantity', '') !~ '^[0-9]+$' then
      raise exception 'INVALID_ITEMS';
    end if;
    v_qty := (v_item ->> 'quantity')::integer;
    if v_qty < 1 or v_qty > 20 then raise exception 'INVALID_ITEMS'; end if;

    select * into v_product
    from public.products
    where id = (v_item ->> 'product_id')::uuid
      and is_published = true
    for update;

    if not found then raise exception 'PRODUCT_UNAVAILABLE'; end if;
    if v_product.stock_quantity is not null and v_product.stock_quantity < v_qty then
      raise exception 'OUT_OF_STOCK';
    end if;
    if v_product.product_type = 'digital' then v_has_digital := true; else v_has_physical := true; end if;
    v_subtotal := v_subtotal + (v_product.price * v_qty);
  end loop;

  if v_has_digital then
    raise exception 'PAYMENT_REQUIRED';
  end if;

  if v_has_physical then
    v_delivery_fee := case when p_shipping_area = 'Dhaka' then 60 else 120 end;
    if char_length(trim(coalesce(p_shipping_address, ''))) < 5 then
      raise exception 'ADDRESS_REQUIRED';
    end if;
  end if;

  v_total := v_subtotal + v_delivery_fee;
  v_order_number := 'HTS-' || to_char(now() at time zone 'utc', 'YYYYMMDD') || '-' || upper(substr(encode(gen_random_bytes(5), 'hex'), 1, 8));

  insert into public.orders (
    id, order_number, user_id, customer_name, customer_phone, customer_email,
    shipping_address, shipping_area, customer_note, currency, subtotal,
    delivery_fee, total, payment_method, payment_status, order_status
  ) values (
    v_order_id, v_order_number, p_user_id, trim(p_customer_name), trim(p_customer_phone),
    nullif(trim(coalesce(p_customer_email, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    case when v_has_physical then coalesce(p_shipping_area, 'Outside') else null end,
    left(coalesce(p_customer_note, ''), 1000), 'BDT', v_subtotal,
    v_delivery_fee, v_total, 'cod', 'unpaid', 'pending'
  );

  for v_item in
    select x.item
    from jsonb_array_elements(p_items) as x(item)
    order by (x.item ->> 'product_id')
  loop
    v_qty := (v_item ->> 'quantity')::integer;
    select * into v_product from public.products where id = (v_item ->> 'product_id')::uuid for update;
    v_line := v_product.price * v_qty;

    insert into public.order_items (
      order_id, product_id, product_name_snapshot, product_slug_snapshot,
      unit_price, quantity, line_total
    ) values (
      v_order_id, v_product.id, v_product.name, v_product.slug,
      v_product.price, v_qty, v_line
    );

    if v_product.stock_quantity is not null then
      update public.products
      set stock_quantity = stock_quantity - v_qty, updated_at = now()
      where id = v_product.id;
    end if;
  end loop;

  return jsonb_build_object(
    'id', v_order_id,
    'order_number', v_order_number,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'total', v_total,
    'currency', 'BDT',
    'payment_status', 'unpaid',
    'order_status', 'pending'
  );
end;
$$;

revoke all on function public.create_order_atomic(uuid, text, text, text, text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.create_order_atomic(uuid, text, text, text, text, text, text, text, jsonb) to service_role;


-- ============================================================
-- SOURCE MIGRATION: 202610290003_storage_policies.sql
-- ============================================================
-- Storage buckets and policies. Private user-media; public product-images.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('user-media', 'user-media', false, 10485760, array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm'])
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "user media read own folder" on storage.objects;
create policy "user media read own folder" on storage.objects for select to authenticated
using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "user media upload own folder" on storage.objects;
create policy "user media upload own folder" on storage.objects for insert to authenticated
with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "user media update own folder" on storage.objects;
create policy "user media update own folder" on storage.objects for update to authenticated
using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "user media delete own folder" on storage.objects;
create policy "user media delete own folder" on storage.objects for delete to authenticated
using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "public product images read" on storage.objects;
create policy "public product images read" on storage.objects for select to anon, authenticated
using (bucket_id = 'product-images');
drop policy if exists "admins upload product images" on storage.objects;
create policy "admins upload product images" on storage.objects for insert to authenticated
with check (bucket_id = 'product-images' and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists "admins update product images" on storage.objects;
create policy "admins update product images" on storage.objects for update to authenticated
using (bucket_id = 'product-images' and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'))
with check (bucket_id = 'product-images' and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists "admins delete product images" on storage.objects;
create policy "admins delete product images" on storage.objects for delete to authenticated
using (bucket_id = 'product-images' and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));


-- ============================================================
-- SOURCE MIGRATION: 202610290004_user_app_state_backup.sql
-- ============================================================
-- Private, per-user backup of the existing single-file app state.
-- This does not replace the normalized store tables; it provides an initial safe
-- cloud backup/restore path while the full UI is migrated incrementally.
create table if not exists public.user_app_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_app_state_object_check check (jsonb_typeof(state_json) = 'object')
);

alter table public.user_app_state enable row level security;

drop policy if exists "user app state select own" on public.user_app_state;
create policy "user app state select own" on public.user_app_state
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "user app state insert own" on public.user_app_state;
create policy "user app state insert own" on public.user_app_state
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists "user app state update own" on public.user_app_state;
create policy "user app state update own" on public.user_app_state
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "user app state delete own" on public.user_app_state;
create policy "user app state delete own" on public.user_app_state
  for delete to authenticated using (user_id = (select auth.uid()));

grant select, insert, update, delete on public.user_app_state to authenticated;
