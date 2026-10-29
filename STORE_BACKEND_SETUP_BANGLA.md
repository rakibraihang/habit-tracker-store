# Store Backend Setup — বাংলা

## Current safety behavior

- The storefront loads products only from public.products rows with is_published = true.
- If there are no published products or the catalog request fails, the website shows sample preview products and disables checkout.
- COD checkout is allowed only for physical products, with a signed-in user and the deployed create-order Edge Function.
- bKash/Nagad and digital product checkout remain disabled until official provider integration and server-side payment verification are implemented.
- Never put the Supabase service-role key in HTML, GitHub, or chat.

## 1. Optional sample catalog seed

File: habit-store-backend/supabase/seed/demo_products_unpublished.sql

Run it in Supabase SQL Editor only if you want sample rows in the database. The seed sets is_published = false and does not overwrite existing slugs. These rows will not appear publicly until explicitly published.

Verify rows with:

select slug, name, product_type, price, stock_quantity, is_published
from public.products
where slug in ('e1','e2','c1','c2','b1','b2','g1','g2','g3','g4')
order by slug;

Do not publish sample products until you approve the actual names, descriptions, prices, stock, delivery fee, images and fulfillment.

## 2. Deploy secure COD order function

Source file: habit-store-backend/supabase/functions/create-order/index.ts

Deploy the Edge Function with the exact name create-order. Use the Supabase CLI from your own computer or the Supabase Edge Functions editor if it supports importing the source.

Required server-side configuration:
- SUPABASE_URL: project root URL, not /rest/v1
- SUPABASE_ANON_KEY: project publishable/anon key
- SUPABASE_SERVICE_ROLE_KEY: secret stored only in Supabase Edge Function secrets
- ALLOWED_ORIGIN: https://rakibraihang.github.io

Supabase may provide the project URL and anon key automatically. Confirm function secrets/settings and only add missing values. Never send the service-role key to ChatGPT or commit it to GitHub.

After deployment, inspect Edge Function logs. Do not test a real order until the function is deployed and the owner has intentionally approved a test product for testing.

## 3. Required checks before launch

- Confirm create_order_atomic exists and execute is granted only to service_role.
- Confirm RLS is enabled on exposed tables and products read policy exposes only published products.
- Confirm anonymous users cannot insert/read arbitrary orders or order_items.
- Test two separate accounts and verify each cannot see the other account's orders.
- Test invalid phone/address, unpublished product, out-of-stock product and duplicate items.
- Confirm COD only; digital orders must fail until verified payment exists.
- Restrict Edge Function CORS to the production website origin.
- Never mark an order paid from a browser-submitted transaction ID.

## 4. bKash/Nagad

Do not add payment numbers or activate manual Send Money instructions yet. Choose an official merchant/payment gateway, store credentials as server-side secrets, implement provider callbacks/server-to-server verification, and only then mark an order paid.

## 5. Remaining limitations

- A secure online admin product-management UI is not yet implemented.
- Sample items shown in preview are not real products and cannot be ordered.
- Online payments and digital fulfillment are disabled.
- Successful GitHub Pages deployment does not prove the live Supabase Edge Function works; real-project integration testing is still required.
