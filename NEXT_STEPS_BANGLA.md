# পরের ধাপ — এক ফাইলে সহজ setup

ভাই, local code আমি প্রস্তুত করে দিয়েছি। Supabase-এর ভেতরে SQL চালানো ছাড়া আমি তোমার account-এ database পরিবর্তন করতে পারি না; এই build environment থেকে তোমার project-এ network access-ও পাওয়া যায়নি।

## তোমার সবচেয়ে ছোট কাজ
1. Supabase Dashboard খোলো: https://supabase.com/dashboard/project/rkgweeatovvkeyxnjamv
2. বাম পাশ থেকে **SQL Editor** → **New query**।
3. `SUPABASE_SETUP_ALL_IN_ONE.sql` ফাইলটি Notepad/VS Code-এ খুলে পুরোটা copy করে SQL Editor-এ paste করো।
4. **Run** চাপো। সফল হলে 13টি public table এবং 2টি storage bucket তৈরি হওয়ার কথা।
5. `VERIFY_SETUP.sql` চালিয়ে table, bucket ও RLS ফলাফল দেখো। Error হলে থামবে এবং error text/screenshot পাঠাবে।

## Local app চালানো
- `START_LOCAL_SERVER.bat`-এ double-click করো (Python installed থাকতে হবে)।
- Browser-এ `http://127.0.0.1:8000/Habit_Tracker_Cloud_Ready.html` খুলবে।
- Cloud → Create account → email confirm (যদি চায়) → sign in → Back up this device।
- প্রথমে app-এর **Export backup** করে রাখবে। Restore করলে বর্তমান browser-এর data replace হয়।

## সৎ অবস্থা
- HTML-এর Cloud auth ও manual private backup/restore UI আছে; JavaScript syntax check পাস করেছে।
- Supabase-এ migration execute/live API test হয়নি। এই environment থেকে project host resolve করা যায়নি।
- Store product/cart/order UI এখনো backend-এর সঙ্গে সম্পূর্ণ wire করা হয়নি। Edge Function deployment, admin account setup, real checkout testing এবং GitHub push বাকি।
- Browser-এ publishable key ছাড়া কোনো secret রাখা হয়নি। কখনো service-role/secret key browser-এ বসাবে না।
