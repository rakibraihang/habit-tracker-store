/*
 * Typed-by-convention API adapter for the Supabase schema.
 * Import { supabase } from './supabase-client.js'.
 * All personal-table access relies on RLS; never accept user_id from UI input.
 */
import { supabase } from './supabase-client.js';

async function checked(query) {
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

async function currentUser() {
  const { data, error } = await supabase.auth.getUser();
  if (error) throw error;
  if (!data.user) throw new Error('Please sign in first.');
  return data.user;
}

export const auth = {
  signUp: async (email, password, displayName = '') => checked(supabase.auth.signUp({
    email, password, options: { data: { display_name: displayName } },
  })),
  signIn: async (email, password) => checked(supabase.auth.signInWithPassword({ email, password })),
  signOut: async () => checked(supabase.auth.signOut()),
  user: currentUser,
  session: async () => {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    return data.session;
  },
  onChange: (callback) => supabase.auth.onAuthStateChange((event, session) => callback(event, session)),
};

export const habits = {
  list: () => checked(supabase.from('habits').select('*').order('sort_order')),
  create: async ({ name, sort_order = 0, color = null }) => {
    const user = await currentUser();
    return checked(supabase.from('habits').insert({ user_id: user.id, name, sort_order, color }).select().single());
  },
  update: (id, patch) => checked(supabase.from('habits').update({ ...patch, updated_at: new Date().toISOString() }).eq('id', id).select().single()),
  remove: (id) => checked(supabase.from('habits').delete().eq('id', id)),
};

export const completions = {
  list: (fromDate, toDate) => checked(supabase.from('habit_completions').select('*').gte('completed_on', fromDate).lte('completed_on', toDate).order('completed_on')),
  mark: async (habitId, date) => {
    const user = await currentUser();
    return checked(supabase.from('habit_completions').upsert(
      { user_id: user.id, habit_id: habitId, completed_on: date },
      { onConflict: 'habit_id,completed_on', ignoreDuplicates: true },
    ).select());
  },
  unmark: (habitId, date) => checked(supabase.from('habit_completions').delete().eq('habit_id', habitId).eq('completed_on', date)),
};

export const journal = {
  list: (fromDate, toDate) => checked(supabase.from('journal_entries').select('*').gte('entry_date', fromDate).lte('entry_date', toDate).order('entry_date', { ascending: false })),
  save: async ({ entry_date, mood = '', body = '' }) => {
    const user = await currentUser();
    return checked(supabase.from('journal_entries').upsert(
      { user_id: user.id, entry_date, mood, body, updated_at: new Date().toISOString() },
      { onConflict: 'user_id,entry_date' },
    ).select().single());
  },
  remove: (id) => checked(supabase.from('journal_entries').delete().eq('id', id)),
};

export const planner = {
  list: (periodType) => {
    let q = supabase.from('planner_documents').select('*').order('period_key');
    if (periodType) q = q.eq('period_type', periodType);
    return checked(q);
  },
  save: async ({ period_type, period_key, payload }) => {
    const user = await currentUser();
    return checked(supabase.from('planner_documents').upsert(
      { user_id: user.id, period_type, period_key, payload, updated_at: new Date().toISOString() },
      { onConflict: 'user_id,period_type,period_key' },
    ).select().single());
  },
  remove: (id) => checked(supabase.from('planner_documents').delete().eq('id', id)),
};

export const shoppingList = {
  list: () => checked(supabase.from('shopping_list_items').select('*').order('created_at')),
  create: async ({ name, quantity = 1, unit_price = 0, is_bought = false }) => {
    const user = await currentUser();
    return checked(supabase.from('shopping_list_items').insert({ user_id: user.id, name, quantity, unit_price, is_bought }).select().single());
  },
  update: (id, patch) => checked(supabase.from('shopping_list_items').update({ ...patch, updated_at: new Date().toISOString() }).eq('id', id).select().single()),
  remove: (id) => checked(supabase.from('shopping_list_items').delete().eq('id', id)),
};

export const store = {
  products: () => checked(supabase.from('products').select('id,slug,name,description,category,product_type,price,currency,stock_quantity,image_path').eq('is_published', true).order('created_at', { ascending: false })),
  cart: () => checked(supabase.from('cart_items').select('id,product_id,quantity,products(id,slug,name,price,currency,product_type,stock_quantity,image_path)')),
  setCartQuantity: async (productId, quantity) => {
    const user = await currentUser();
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 20) throw new Error('Quantity must be from 1 to 20.');
    return checked(supabase.from('cart_items').upsert({ user_id: user.id, product_id: productId, quantity, updated_at: new Date().toISOString() }, { onConflict: 'user_id,product_id' }).select().single());
  },
  removeFromCart: (productId) => checked(supabase.from('cart_items').delete().eq('product_id', productId)),
  wishlist: () => checked(supabase.from('wishlist_items').select('product_id,created_at,products(id,slug,name,price,currency,image_path)')),
  addToWishlist: async (productId) => {
    const user = await currentUser();
    return checked(supabase.from('wishlist_items').upsert({ user_id: user.id, product_id: productId }, { onConflict: 'user_id,product_id', ignoreDuplicates: true }));
  },
  removeFromWishlist: (productId) => checked(supabase.from('wishlist_items').delete().eq('product_id', productId)),
  orders: () => checked(supabase.from('orders').select('id,order_number,customer_name,subtotal,delivery_fee,total,currency,payment_method,payment_status,order_status,created_at,order_items(*)').order('created_at', { ascending: false })),
  createCODOrder: async (payload) => {
    const session = await auth.session();
    if (!session) throw new Error('Please sign in before placing an order.');
    const { data, error } = await supabase.functions.invoke('create-order', { body: payload });
    if (error) throw error;
    return data.order;
  },
};

export const media = {
  async uploadUserFile(file) {
    const user = await currentUser();
    if (!(file instanceof File)) throw new Error('Choose a file first.');
    const isImage = file.type.startsWith('image/');
    const isVideo = file.type.startsWith('video/');
    if (!isImage && !isVideo) throw new Error('Only images and videos are supported.');
    if (file.size > 10 * 1024 * 1024) throw new Error('File must be 10 MB or smaller.');
    const safeName = file.name.toLowerCase().replace(/[^a-z0-9._-]+/g, '-').slice(-100) || 'upload';
    const path = `${user.id}/${crypto.randomUUID()}-${safeName}`;
    const { error: uploadError } = await supabase.storage.from('user-media').upload(path, file, { upsert: false, contentType: file.type });
    if (uploadError) throw uploadError;
    const { data, error } = await supabase.from('media_assets').insert({ user_id: user.id, media_type: isImage ? 'image' : 'video', title: file.name.slice(0, 200), storage_path: path }).select().single();
    if (error) {
      await supabase.storage.from('user-media').remove([path]);
      throw error;
    }
    return data;
  },
  async signedUrl(path, expiresInSeconds = 300) {
    const { data, error } = await supabase.storage.from('user-media').createSignedUrl(path, expiresInSeconds);
    if (error) throw error;
    return data.signedUrl;
  },
  remove: async (id, path) => {
    const { error } = await supabase.storage.from('user-media').remove([path]);
    if (error) throw error;
    return checked(supabase.from('media_assets').delete().eq('id', id));
  },
};
