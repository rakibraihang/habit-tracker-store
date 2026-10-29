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
