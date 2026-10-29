# Habit Tracker + Store — Backend starter

This repository is a prepared Supabase backend implementation for the existing single-file HTML app. It is **not yet deployed** to your Supabase account, and the HTML frontend has not yet been switched from `localStorage` to cloud persistence.

## Included

- `supabase/migrations/202610290001_initial_schema.sql`: database tables and RLS policies.
- `supabase/migrations/202610290002_atomic_order_creation.sql`: atomic order RPC; prices are loaded from database rows, stock is checked/decremented inside the transaction, and totals are calculated server-side.
- `supabase/migrations/202610290003_storage_policies.sql`: private user media and public product-image storage buckets/policies.
- `supabase/functions/create-order/index.ts`: authenticated Edge Function; validates caller/session and request data, then calls the atomic RPC.
- `supabase/seed/demo_products_unpublished.sql`: optional sample catalog rows, all unpublished and not production-approved.
- `src/supabase-client.example.js`: browser client starter for sign-up/sign-in, public products and order calls.
- `tests/rls-smoke-test.sql`: manual SQL checks to use after creating two test accounts.

## Deployment boundary

The SQL and function code must be applied to the user's Supabase project. This workspace does not have authenticated access to that project, so no remote changes have been made and no live deployment is claimed.

## Apply database migrations

For a new/empty Supabase project, open SQL Editor and run the three migration files in filename order. Review any error and stop if one occurs. Do not run these on a production database without a backup and migration review.

## Deploy the Edge Function

With Supabase CLI installed and logged in on your own machine:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy create-order --no-verify-jwt
```

The function verifies the user's bearer token itself. Set `ALLOWED_ORIGIN` to your exact website origin for production (instead of `*`) in the Supabase Edge Function secrets/settings. Supabase supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` to hosted functions. Never put the service-role key in HTML or browser code.

## Seed products

Optionally run `supabase/seed/demo_products_unpublished.sql` after the migrations. It creates unpublished sample rows only; review and edit real product details and stock before publishing.

The current HTML has a demo product list (`e1`, `e2`, `c1`, etc.) with no database UUIDs. Before connecting the store UI, add/confirm actual product rows in `public.products`, then map frontend cart items to returned product UUIDs. Do not silently assume the demo product catalog, stock, payment methods, or prices are production-approved.

## Current checkout scope

- Requires a signed-in Supabase user.
- Currently accepts physical-product Cash on Delivery orders only; delivery fee is calculated server-side as BDT 60 inside Dhaka and BDT 120 outside Dhaka, matching the current HTML constants. Review these values before launch.
- Digital-product orders are blocked until a real payment provider and verified server callbacks are implemented.
- This endpoint supports order creation, not payment collection or verification.
- It does not mark payments as paid or deliver digital goods.
- COD is the safe initial method; online methods need a payment provider integration and verified server callbacks before they can be enabled.
- Guest checkout, email/SMS notifications, product image storage policies, admin UI and frontend migration remain separate implementation steps.

## Auth configuration

In Supabase Authentication settings, configure the production site URL, redirect URLs, email confirmation and password reset flow. Use test accounts to verify that one user cannot read another user's private rows.
