/* Copy to supabase-client.js and replace the two placeholders.
   Only the project URL and publishable/anon key may be used in the browser.
   NEVER place SUPABASE_SERVICE_ROLE_KEY in this file or in HTML. */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://YOUR_PROJECT_REF.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
});

export async function signUp(email, password, displayName = '') {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { display_name: displayName } },
  });
  if (error) throw error;
  return data;
}

export async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export async function getPublishedProducts() {
  const { data, error } = await supabase.from('products')
    .select('id, slug, name, description, category, product_type, price, currency, stock_quantity, image_path')
    .eq('is_published', true).order('created_at', { ascending: false });
  if (error) throw error;
  return data;
}

export async function createOrder(order) {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Please sign in before placing an order.');
  const { data, error } = await supabase.functions.invoke('create-order', { body: order });
  if (error) throw error;
  return data.order;
}
