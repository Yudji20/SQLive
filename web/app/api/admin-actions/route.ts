import { createSupabaseAdminClient } from "@/lib/supabase-admin";

const allowedActions = new Set([
  "spawn_entity",
  "bless_entity",
  "storm",
  "observe",
]);

function hasSupabaseConfig() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY,
  );
}

export async function POST(request: Request) {
  const body = await request.json().catch(() => ({}));
  const actionType = String(body.action_type ?? "");

  if (!allowedActions.has(actionType)) {
    return Response.json({ error: "Unsupported admin action" }, { status: 400 });
  }

  if (!hasSupabaseConfig()) {
    return Response.json({
      ok: true,
      mode: "mock",
      action: {
        action_type: actionType,
        payload: body.payload ?? {},
        status: "pending",
      },
    });
  }

  const supabase = createSupabaseAdminClient().schema("alife");
  const worldSlug = process.env.SQLIVE_WORLD_SLUG ?? "eldergrove";

  const { data: world, error: worldError } = await supabase
    .from("worlds")
    .select("id")
    .eq("slug", worldSlug)
    .single<{ id: number }>();

  if (worldError || !world) {
    return Response.json(
      { error: worldError?.message ?? `World ${worldSlug} not found` },
      { status: 500 },
    );
  }

  const { data, error } = await supabase
    .from("admin_actions")
    .insert({
      world_id: world.id,
      action_type: actionType,
      payload: body.payload ?? {},
      status: "pending",
    })
    .select("id, action_type, status, requested_at")
    .single();

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  return Response.json({ ok: true, mode: "supabase", action: data });
}

