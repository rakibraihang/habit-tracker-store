import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("ALLOWED_ORIGIN") ?? "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function cleanText(value: unknown, max: number): string {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(500, { error: "Server configuration is incomplete" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json(401, { error: "Sign in before placing an order" });

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) return json(401, { error: "Session is invalid or expired" });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Request body must be valid JSON" });
  }

  const customerName = cleanText(body.customer_name, 120);
  const customerPhone = cleanText(body.customer_phone, 30);
  const customerEmail = cleanText(body.customer_email, 254) || authData.user.email || "";
  const shippingAddress = cleanText(body.shipping_address, 500);
  const shippingArea = body.shipping_area === "Dhaka" ? "Dhaka" : "Outside";
  const customerNote = cleanText(body.customer_note, 1000);
  const paymentMethod = body.payment_method === "cod" ? "cod" : "other";
  const rawItems = body.items;

  if (customerName.length < 2) return json(400, { error: "Enter a valid customer name" });
  if (customerPhone.replace(/\D/g, "").length < 8) return json(400, { error: "Enter a valid phone number" });
  if (!Array.isArray(rawItems) || rawItems.length < 1 || rawItems.length > 50) {
    return json(400, { error: "Order must contain between 1 and 50 distinct items" });
  }

  const items: Array<{ product_id: string; quantity: number }> = [];
  const seen = new Set<string>();
  for (const item of rawItems) {
    if (!item || typeof item !== "object") return json(400, { error: "Invalid item" });
    const productId = cleanText((item as Record<string, unknown>).product_id, 80);
    const quantity = Number((item as Record<string, unknown>).quantity);
    if (!/^[0-9a-f-]{36}$/i.test(productId) || !Number.isInteger(quantity) || quantity < 1 || quantity > 20) {
      return json(400, { error: "Each item needs a valid product UUID and quantity from 1 to 20" });
    }
    if (seen.has(productId)) return json(400, { error: "Send each product once with its total quantity" });
    seen.add(productId);
    items.push({ product_id: productId, quantity });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await admin.rpc("create_order_atomic", {
    p_user_id: authData.user.id,
    p_customer_name: customerName,
    p_customer_phone: customerPhone,
    p_customer_email: customerEmail || null,
    p_shipping_address: shippingAddress || null,
    p_shipping_area: shippingArea,
    p_customer_note: customerNote,
    p_payment_method: paymentMethod,
    p_items: items,
  });

  if (error) {
    console.error("create_order_atomic failed", { code: error.code, message: error.message });
    if (error.message?.includes("OUT_OF_STOCK")) return json(409, { error: "One or more products are out of stock" });
    if (error.message?.includes("PRODUCT_UNAVAILABLE")) return json(400, { error: "One or more products are unavailable" });
    if (error.message?.includes("INVALID_ITEMS")) return json(400, { error: "Order items are invalid" });
    if (error.message?.includes("PAYMENT_REQUIRED")) return json(400, { error: "Digital products require verified online payment; digital checkout is not enabled yet" });
    if (error.message?.includes("PAYMENT_METHOD_UNAVAILABLE")) return json(400, { error: "This payment method is not enabled yet" });
    if (error.message?.includes("ADDRESS_REQUIRED")) return json(400, { error: "A delivery address is required for physical products" });
    return json(500, { error: "Order could not be created. Please try again later." });
  }

  return json(201, { order: data, message: "Order created. Payment is not marked paid by this endpoint." });
});
