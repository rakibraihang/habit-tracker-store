# Habit Tracker — GitHub-ready package

## কী আছে
- `index.html`: GitHub Pages-এর root homepage (Cloud sign-in ও manual backup/restore UI সহ)
- `habit-store-backend/`: Supabase migrations, API adapter এবং `create-order` Edge Function source
- `SUPABASE_SETUP_ALL_IN_ONE.sql`: Supabase SQL Editor-এ চালানোর combined setup script
- `VERIFY_SETUP.sql`: setup যাচাইয়ের SQL

## গুরুত্বপূর্ণ অবস্থা
- ফ্রন্টএন্ডে Supabase project URL এবং publishable key configured আছে।
- SQL script এখনো live Supabase project-এ চালানো/যাচাই করা হয়নি।
- Cloud Backup কাজ করতে `user_app_state` table ও RLS policy তৈরি থাকা দরকার।
- Store-এর product/cart/checkout এখনও সম্পূর্ণ Supabase backend-এ wired নয়; বর্তমান Store flow local demo-ধরনের।
- Edge Function source দেওয়া আছে, কিন্তু live project-এ deploy করা হয়নি।
- কোনো `service_role` key/password/token এই package-এ থাকা উচিত নয়।

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
