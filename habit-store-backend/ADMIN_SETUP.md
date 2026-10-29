# Admin account setup (manual, after creating your own account)

Do not run this until you have signed up through Supabase Auth using the email you control. Replace the email below with that exact account email and run it as the project owner in the Supabase SQL Editor. Do not let any public frontend expose an admin-role editing control.

```sql
update public.profiles p
set role = 'admin', updated_at = now()
from auth.users u
where p.id = u.id
  and lower(u.email) = lower('YOUR_VERIFIED_ADMIN_EMAIL');
```

Then confirm exactly one row was updated and test the admin access. Never grant admin to an unverified or user-supplied email.
