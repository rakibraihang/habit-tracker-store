# Store Launch Guide (Bangla)

## Current status

- The Habit Tracker static website deploys through GitHub Pages.
- Public-schema tables have Row Level Security enabled.
- The store catalog reads only published products from the Supabase products table.
- COD order creation uses the create-order Edge Function with server-side validation and stock locking.
- The admin-products Edge Function was added for secure product management. It requires a valid Supabase session and profiles.role = admin before reading or changing product data.
- The only existing profile was promoted to admin so the store owner account can use the product manager.
- bKash, Nagad, Rocket and card payments have NOT been enabled. Digital checkout remains disabled.
- No live products, orders or payment transactions were seeded.

## How to use the product manager

1. Open https://rakibraihang.github.io/habit-tracker-store/
2. Sign in with your account in the Cloud Backup panel.
3. Open the Store and choose Manage products.
4. Enter product name, slug, price in BDT, category, type, stock, description and image path.
5. Keep new products unpublished until the real price, description, stock and image are checked. Publish only after you approve the listing.
6. Upload product images into the Supabase Storage product-images bucket first. Use the relative path inside the bucket, for example products/item-name.jpg.
7. Physical products in categories such as book or gadget can use COD. Digital products may be listed, but checkout/payment fulfilment is not enabled yet.

## Security boundaries

- Only the Supabase publishable key belongs in browser code. Never put a service-role key, database password or secret in GitHub or frontend code.
- The product-management API checks the admin role server-side. Hiding a button alone is not security.
- The product manager does not delete products; unpublish them instead to avoid breaking historical order references.
- COD orders remain unpaid. Do not mark an order paid without verified payment-provider confirmation.
- No real payment keys or provider settings were added.

## Required before a public store launch

- Add real products, verified prices, inventory, images, delivery charges, business contact information and accurate policies.
- Create a physical product as unpublished, review the storefront, then publish it only after owner approval.
- Run an end-to-end test: sign in, submit a COD order, verify the database order and order items, and verify the My Orders view.
- Enable leaked-password protection in Supabase Auth settings.
- Replace placeholder privacy, terms, refund/return, delivery and contact details with real business information.
- Do not enable digital checkout or online payments until verified payment integration, digital fulfilment and receipt/support flows are implemented.
- Manually test backup/restore and mobile layout in a real browser.

## GitHub QA

After a push, the HTML JavaScript QA workflow checks inline scripts and runs node --check admin-manager.js. Check the Deploy static Habit Tracker to GitHub Pages workflow for deployment status.
