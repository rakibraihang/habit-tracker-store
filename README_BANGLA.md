# Habit Tracker — GitHub-ready package

## কী আছে
- `index.html`: GitHub Pages-এর root homepage (Cloud sign-in ও manual backup/restore UI সহ)
- `habit-store-backend/`: Supabase migrations, API adapter এবং `create-order` Edge Function source
- `SUPABASE_SETUP_ALL_IN_ONE.sql`: Supabase SQL Editor-এ চালানোর combined setup script
- `VERIFY_SETUP.sql`: setup যাচাইয়ের SQL

## বর্তমান অবস্থা

- Frontend GitHub Pages-এ deploy হয়; Supabase project connected।
- Habit Tracker cloud backup এবং Supabase data tables-এর RLS configured।
- Store catalog Supabase-এর published products থেকে load হয়।
- COD order-এর জন্য secure create-order Edge Function আছে; server-side price/stock validation করে এবং payment unpaid রাখে।
- Secure product manager-এর জন্য admin-products Edge Function ও Manage products UI যোগ করা হয়েছে।
- Admin access শুধু server-side profiles.role = admin যাচাইয়ের পর মেলে।
- কোনো বাস্তব product/order/payment seed করা হয়নি। Product manager-এ যোগ করা নতুন item default-এ unpublished থাকবে।
- bKash/Nagad/Rocket/card payment ও digital fulfilment এখনো enabled নয়। Real payment নেওয়ার আগে provider integration এবং server-side payment verification দরকার।
- Launch steps ও test checklist: STORE_LAUNCH_GUIDE_BANGLA.md

## নিরাপত্তা

- Browser code-এ শুধু publishable key রাখা যাবে; service-role key বা database secret কখনো নয়।
- Public schema-এর সব ১৩টি table-এ RLS enabled।
- Admin function-এ JWT/session এবং admin role server-side যাচাই হয়।
- Product delete না করে unpublish করার workflow রাখা হয়েছে যাতে পুরোনো order reference অক্ষত থাকে।

## GitHub-এ আপলোড
1. ZIP extract করো।
2. GitHub repository-তে `Add file` → `Upload files` নির্বাচন করো।
3. Extract করা `HabitTracker_GitHub_Ready` ফোল্ডারের ভেতরের সব ফাইল ও folder upload করো—ফোল্ডারটিকে parent হিসেবে upload করবে না। `index.html` repository root-এ থাকতে হবে।
4. নিচে গিয়ে commit করো।
5. Settings → Pages → Build and deployment-এ GitHub Actions source নির্বাচন করো (workflow file included)।

## Supabase
Dashboard → SQL Editor → New query-তে `SUPABASE_SETUP_ALL_IN_ONE.sql`-এর সম্পূর্ণ contents paste করে Run করো। Error এলে বারবার Run না করে error screenshot দেখে fix করো। তারপর `VERIFY_SETUP.sql` চালাও।

## Store production status
এটি এখনই পূর্ণাঙ্গ live e-commerce checkout নয়। Products, cart, checkout, real payment confirmation/email delivery, secure admin product management এবং end-to-end tests শেষ না হওয়া পর্যন্ত live customer payments নেওয়া উচিত নয়.
