# Local integration configuration

## Supabase client configuration
- Project root URL: `https://rkgweeatovvkeyxnjamv.supabase.co`
- Publishable key: configured in `src/supabase-client.js`
- The provided URL originally ended in `/rest/v1/`. The Supabase JS SDK needs the project root URL, so the `/rest/v1/` suffix has intentionally been removed in the client configuration.

## Files prepared
- `src/supabase-client.js`: configured Supabase JS client and a safe products-table connection smoke test.
- `src/habit-store-api.js`: auth, habits, completions, journal, planner, shopping list, store, orders and media API adapter.
- `supabase/migrations/`: database schema, security policies and atomic COD order flow.
- `Habit_Tracker_LocalStorage_Current.html`: snapshot of the existing single-file UI for reference.

## Important status
This is a locally configured integration package, **not a live deployment**. The SQL migrations have not been run against the project, the Edge Function has not been deployed, and the existing HTML still saves app state in browser `localStorage`. Do not treat the store or personal data as cloud-synced yet.

## Safe next steps
1. In the Supabase dashboard, review and apply the three migration files in order to the intended project. Stop if SQL Editor reports an error.
2. Test authentication and the `products` read with `checkSupabaseConnection()` from a local development page served over `http://localhost` (not by opening an ES module file directly as `file://`).
3. Deploy the `create-order` Edge Function only after reviewing its environment and origin settings.
4. Then connect UI state to the adapter and run two-user RLS tests before using real data.

Never provide a database password, personal access token, `service_role`, or `sb_secret_...` key. The publishable key is intended for client use, but it does not replace RLS.
