import { createSupabaseAdminClient } from "@/lib/supabase-admin";

function mask(value: string | undefined) {
  if (!value) {
    return { configured: false };
  }

  return {
    configured: true,
    prefix: value.slice(0, Math.min(12, value.length)),
    length: value.length,
  };
}

export async function GET() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const worldSlug = process.env.SQLIVE_WORLD_SLUG ?? "eldergrove";

  const env = {
    supabaseUrl: {
      configured: Boolean(url),
      valueLooksLikeUrl: Boolean(url?.startsWith("https://") && url.includes(".supabase.co")),
      length: url?.length ?? 0,
    },
    serviceRoleKey: mask(serviceKey),
    publishableKey: mask(publishableKey),
    worldSlug,
  };

  if (!url || !serviceKey) {
    return Response.json({ ok: false, env, error: "Missing Supabase server config" });
  }

  try {
    const supabase = createSupabaseAdminClient().schema("alife");
    const { data, error } = await supabase
      .from("worlds")
      .select("id, slug, name, tick_no")
      .eq("slug", worldSlug)
      .maybeSingle();

    if (error) {
      return Response.json({
        ok: false,
        env,
        supabase: {
          error: error.message,
          code: error.code,
          details: error.details,
          hint: error.hint,
        },
      });
    }

    return Response.json({
      ok: Boolean(data),
      env,
      world: data,
    });
  } catch (error) {
    return Response.json({
      ok: false,
      env,
      error: error instanceof Error ? error.message : "Unknown health check error",
    });
  }
}
