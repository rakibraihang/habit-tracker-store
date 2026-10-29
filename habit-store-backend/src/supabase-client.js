/*
 * Configured for the user's Supabase project.
 * This is a PUBLIC browser key, not a secret. RLS must be correctly applied
 * before any personal data is stored in the database.
 * Supabase client expects the project root URL, not the /rest/v1 endpoint.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const SUPABASE_URL = 'https://rkgweeatovvkeyxnjamv.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_yNeszQqLTdTQzb4actuPsA_wHtI4fm1';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

export async function checkSupabaseConnection() {
  // This public read is a safe smoke test; it does not require sign-in.
  // An error can mean migrations are not applied or Data API access is not configured.
  const { data, error } = await supabase.from('products')
    .select('id', { head: true, count: 'exact' })
    .limit(1);
  if (error) {
    return { ok: false, message: error.message, code: error.code ?? null };
  }
  return { ok: true, productCount: data?.length ?? 0 };
}
