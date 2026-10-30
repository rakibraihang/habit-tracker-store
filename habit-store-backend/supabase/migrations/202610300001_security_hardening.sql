-- Security hardening applied to the live project on 2026-10-30.
-- Keep ordinary users from changing profile role or inserting arbitrary profiles.
REVOKE INSERT, UPDATE ON TABLE public.profiles FROM anon;
REVOKE INSERT, UPDATE ON TABLE public.profiles FROM authenticated;
GRANT UPDATE (display_name) ON TABLE public.profiles TO authenticated;

-- These SECURITY DEFINER routines are for trusted database lifecycle use only.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;
