import { createClient } from "https://esm.sh/@supabase/supabase-js@2.115.0";

type TickRequest = {
  world_slug?: string;
  world_id?: number;
  ticks?: number;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const cronSecret = Deno.env.get("SQLIVE_CRON_SECRET");
  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");

  if (!cronSecret || token !== cronSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Supabase environment is not configured" }, 500);
  }

  const payload = (await request.json().catch(() => ({}))) as TickRequest;
  const worldSlug = payload.world_slug ?? "eldergrove";
  const ticks = Math.max(1, Math.min(payload.ticks ?? 1, 50));

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  let worldId = payload.world_id;

  if (!worldId) {
    const { data, error } = await supabase
      .schema("alife")
      .from("worlds")
      .select("id")
      .eq("slug", worldSlug)
      .single();

    if (error) {
      return json({ error: error.message }, 500);
    }

    if (!data) {
      return json({ error: `World ${worldSlug} not found` }, 404);
    }

    worldId = data.id;
  }

  const executedTicks: number[] = [];

  for (let index = 0; index < ticks; index += 1) {
    const { data, error } = await supabase
      .schema("alife")
      .rpc("execute_world_tick", { p_world_id: worldId });

    if (error) {
      return json({ error: error.message, executedTicks }, 500);
    }

    executedTicks.push(data as number);
  }

  return json({
    ok: true,
    world_id: worldId,
    world_slug: worldSlug,
    executed_ticks: executedTicks,
  });
});
