import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.0";

const origin = Deno.env.get("ALLOWED_ORIGIN") ?? "";
const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
  "Vary": "Origin",
  "Content-Type": "application/json; charset=utf-8",
};
if (origin) corsHeaders["Access-Control-Allow-Origin"] = origin;

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}
function text(v: unknown, max: number): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}
function validSlug(v: string): boolean {
  return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(v);
}
function productInput(body: Record<string, unknown>, partial = false) {
  const out: Record<string, unknown> = {};
  if (!partial || "slug" in body) {
    const slug = text(body.slug, 160).toLowerCase();
    if (!validSlug(slug)) throw new Error("SLUG_INVALID");
    out.slug = slug;
  }
  if (!partial || "name" in body) {
    const name = text(body.name, 200);
    if (name.length < 2) throw new Error("NAME_INVALID");
    out.name = name;
  }
  for (const key of ["description", "category", "product_type", "currency", "image_path"] as const) {
    if (partial && !(key in body)) continue;
    const max = key === "description" ? 5000 : key === "image_path" ? 500 : key === "category" ? 60 : 3;
    const value = text(body[key], max);
    if (key === "product_type" && !["physical", "digital"].includes(value)) throw new Error("PRODUCT_TYPE_INVALID");
    if (key === "currency" && value !== "BDT") throw new Error("CURRENCY_INVALID");
    if (key === "category" && !value) throw new Error("CATEGORY_INVALID");
    out[key] = key === "image_path" && !value ? null : value;
  }
  if (!partial || "price" in body) {
    const price = Number(body.price);
    if (!Number.isFinite(price) || price < 0 || price > 100000000) throw new Error("PRICE_INVALID");
    out.price = Math.round(price * 100) / 100;
  }
  if (!partial || "stock_quantity" in body) {
    const stock = body.stock_quantity === null || body.stock_quantity === "" ? null : Number(body.stock_quantity);
    if (stock !== null && (!Number.isInteger(stock) || stock < 0 || stock > 10000000)) throw new Error("STOCK_INVALID");
    out.stock_quantity = stock;
  }
  if (partial && "is_published" in body) {
    if (typeof body.is_published !== "boolean") throw new Error("PUBLISH_FLAG_INVALID");
    out.is_published = body.is_published;
  }
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (!["GET", "POST", "PATCH"].includes(req.method)) return json(405, { error: "Method not allowed" });
  if (!origin || req.headers.get("origin") !== origin) return json(403, { error: "Origin not allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json(500, { error: "Server configuration is incomplete" });

  const header = req.headers.get("Authorization") ?? "";
  const token = header.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json(401, { error: "Sign in with the store owner account first" });

  const auth = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await auth.auth.getUser(token);
  if (authError || !authData.user) return json(401, { error: "Session is invalid or expired" });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await admin.from("profiles").select("role").eq("id", authData.user.id).maybeSingle();
  if (profileError) {
    console.error("admin-products role lookup failed", { code: profileError.code });
    return json(500, { error: "Could not verify administrator access" });
  }
  if (profile?.role !== "admin") return json(403, { error: "This account does not have store administrator access" });

  if (req.method === "GET") {
    const { data, error } = await admin.from("products")
      .select("id,slug,name,description,category,product_type,price,currency,stock_quantity,image_path,is_published,created_at,updated_at")
      .order("created_at", { ascending: false }).limit(200);
    if (error) {
      console.error("admin-products list failed", { code: error.code });
      return json(500, { error: "Could not load products" });
    }
    return json(200, { products: data ?? [] });
  }

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json(400, { error: "Request body must be valid JSON" }); }

  try {
    if (req.method === "POST") {
      const input = productInput(body);
      input.is_published = body.is_published === true;
      const { data, error } = await admin.from("products").insert(input).select("*").single();
      if (error) {
        console.error("admin-products create failed", { code: error.code });
        if (error.code === "23505") return json(409, { error: "A product with this slug already exists" });
        return json(400, { error: "Could not create product. Check the fields and try again." });
      }
      return json(201, { product: data });
    }

    const id = text(body.id, 80);
    if (!/^[0-9a-f-]{36}$/i.test(id)) return json(400, { error: "A valid product ID is required" });
    const input = productInput(body, true);
    if (Object.keys(input).length === 0) return json(400, { error: "No editable fields were provided" });
    input.updated_at = new Date().toISOString();
    const { data, error } = await admin.from("products").update(input).eq("id", id).select("*").maybeSingle();
    if (error) {
      console.error("admin-products update failed", { code: error.code });
      if (error.code === "23505") return json(409, { error: "A product with this slug already exists" });
      return json(400, { error: "Could not update product. Check the fields and try again." });
    }
    if (!data) return json(404, { error: "Product not found" });
    return json(200, { product: data });
  } catch (e) {
    const message = e instanceof Error ? e.message : "";
    const messages: Record<string, string> = {
      SLUG_INVALID: "Slug must use lowercase letters, numbers and hyphens",
      NAME_INVALID: "Product name must contain at least 2 characters",
      PRODUCT_TYPE_INVALID: "Product type must be physical or digital",
      CURRENCY_INVALID: "Only BDT currency is currently supported",
      CATEGORY_INVALID: "Enter a product category",
      PRICE_INVALID: "Price must be a valid non-negative number",
      STOCK_INVALID: "Stock must be a non-negative integer or left blank for unlimited stock",
      PUBLISH_FLAG_INVALID: "Publish status must be true or false",
    };
    return json(400, { error: messages[message] ?? "Invalid product fields" });
  }
});
