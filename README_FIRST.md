# Habit Tracker + Store — build package

## Start here
1. Open `NEXT_STEPS_BANGLA.md` for the short setup steps in Bangla.
2. Use `SUPABASE_SETUP_ALL_IN_ONE.sql` in Supabase SQL Editor to create the schema, RLS policies, storage buckets and private cloud backup table.
3. Run `VERIFY_SETUP.sql` to confirm the setup.
4. Double-click `START_LOCAL_SERVER.bat` to open the local HTML (requires Python).

## Honest implementation status
- The single-file Habit Tracker HTML has email sign-in/create account UI and manual private cloud backup/restore.
- Backup includes the app state and light/dark theme; restore accepts earlier unwrapped backups too.
- The database schema and Edge Function source are included.
- No SQL has been executed in the user's Supabase project from this environment. The store product/cart/checkout UI is not fully connected to the backend, the Edge Function is not deployed, and GitHub was not updated.
- Keep a local Export backup before using Restore. Never place a Supabase secret/service-role key in browser code.
