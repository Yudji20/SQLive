import { createSupabaseAdminClient } from "@/lib/supabase-admin";
import { getWorldSnapshot } from "@/lib/mock-world";

type DbWorld = {
  id: number;
  slug: string;
  name: string;
  width: number;
  height: number;
  tick_no: number;
};

type DbTile = {
  x: number;
  y: number;
  terrain_type: string;
};

type DbEntity = {
  id: number;
  name: string | null;
  generation: number;
  x: number;
  y: number;
  energy: number;
  gene_speed: number;
  gene_strength: number;
  gene_mass: number;
  species: {
    name: string;
  } | null;
};

type DbEvent = {
  id: number;
  tick_no: number;
  title: string;
  description: string | null;
};

type DbMetric = {
  population: number;
  alive_entities: number;
  resource_total: number;
  avg_energy: number | null;
  avg_generation: number | null;
  avg_gene_speed: number | null;
  avg_gene_metabolism: number | null;
  avg_gene_strength: number | null;
  avg_gene_mass: number | null;
};

function hasSupabaseConfig() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY,
  );
}

function formatNumber(value: number | null | undefined, digits = 1) {
  if (value === null || value === undefined) {
    return "-";
  }

  return Number(value).toFixed(digits);
}

export async function getWorldSnapshotData() {
  if (!hasSupabaseConfig()) {
    return getWorldSnapshot();
  }

  const supabase = createSupabaseAdminClient().schema("alife");
  const worldSlug = process.env.SQLIVE_WORLD_SLUG ?? "eldergrove";

  const { data: world, error: worldError } = await supabase
    .from("worlds")
    .select("id, slug, name, width, height, tick_no")
    .eq("slug", worldSlug)
    .single<DbWorld>();

  if (worldError || !world) {
    return getWorldSnapshot();
  }

  const [tilesResult, entitiesResult, eventsResult, metricsResult] = await Promise.all([
    supabase
      .from("tiles")
      .select("x, y, terrain_type")
      .eq("world_id", world.id)
      .order("y", { ascending: true })
      .order("x", { ascending: true })
      .returns<DbTile[]>(),
    supabase
      .from("entities")
      .select("id, name, generation, x, y, energy, gene_speed, gene_strength, gene_mass, species:species_id(name)")
      .eq("world_id", world.id)
      .eq("alive", true)
      .order("generation", { ascending: false })
      .limit(20)
      .returns<DbEntity[]>(),
    supabase
      .from("event_log")
      .select("id, tick_no, title, description")
      .eq("world_id", world.id)
      .order("tick_no", { ascending: false })
      .order("id", { ascending: false })
      .limit(20)
      .returns<DbEvent[]>(),
    supabase
      .from("world_metrics")
      .select(
        "population, alive_entities, resource_total, avg_energy, avg_generation, avg_gene_speed, avg_gene_metabolism, avg_gene_strength, avg_gene_mass",
      )
      .eq("world_id", world.id)
      .order("tick_no", { ascending: false })
      .limit(1)
      .maybeSingle<DbMetric>(),
  ]);

  if (tilesResult.error || entitiesResult.error || eventsResult.error) {
    return getWorldSnapshot();
  }

  const metric = metricsResult.data;

  return {
    name: world.name,
    tickNo: world.tick_no,
    width: world.width,
    height: world.height,
    tiles: (tilesResult.data ?? []).map((tile) => ({
      x: tile.x,
      y: tile.y,
      terrain: tile.terrain_type,
    })),
    entities: (entitiesResult.data ?? []).map((entity) => ({
      id: entity.id,
      name: entity.name ?? `Entity ${entity.id}`,
      species: entity.species?.name ?? "Unknown",
      generation: entity.generation,
      energy: Number(entity.energy.toFixed(0)),
      speed: Number(entity.gene_speed.toFixed(2)),
      strength: Number(entity.gene_strength.toFixed(2)),
      mass: Number(entity.gene_mass.toFixed(2)),
      x: entity.x,
      y: entity.y,
    })),
    events: (eventsResult.data ?? []).map((event) => ({
      id: event.id,
      tick: event.tick_no,
      title: event.title,
      description: event.description ?? "",
    })),
    metrics: [
      { label: "Population", value: String(metric?.alive_entities ?? metric?.population ?? "-") },
      { label: "Avg energy", value: formatNumber(metric?.avg_energy) },
      { label: "Avg gen", value: formatNumber(metric?.avg_generation) },
      { label: "Resources", value: formatNumber(metric?.resource_total, 0) },
      { label: "Avg speed", value: formatNumber(metric?.avg_gene_speed, 2) },
      { label: "Avg metabolism", value: formatNumber(metric?.avg_gene_metabolism, 2) },
      { label: "Avg strength", value: formatNumber(metric?.avg_gene_strength, 2) },
      { label: "Avg mass", value: formatNumber(metric?.avg_gene_mass, 2) },
    ],
  };
}

export async function executeWorldTick(ticks = 1) {
  if (!hasSupabaseConfig()) {
    const world = await getWorldSnapshot();

    return {
      ok: true,
      mode: "mock",
      world: {
        name: world.name,
        tickNo: world.tickNo + ticks,
      },
    };
  }

  const supabase = createSupabaseAdminClient().schema("alife");
  const worldSlug = process.env.SQLIVE_WORLD_SLUG ?? "eldergrove";

  const { data: world, error: worldError } = await supabase
    .from("worlds")
    .select("id, name")
    .eq("slug", worldSlug)
    .single<{ id: number; name: string }>();

  if (worldError || !world) {
    throw new Error(worldError?.message ?? `World ${worldSlug} not found`);
  }

  const executedTicks: number[] = [];
  const safeTicks = Math.max(1, Math.min(ticks, 50));

  for (let index = 0; index < safeTicks; index += 1) {
    const { data, error } = await supabase.rpc("execute_world_tick", {
      p_world_id: world.id,
    });

    if (error) {
      throw new Error(error.message);
    }

    executedTicks.push(data as number);
  }

  return {
    ok: true,
    mode: "supabase",
    world: {
      name: world.name,
      tickNo: executedTicks.at(-1),
    },
    executedTicks,
  };
}

type ResetWorldInput = {
  slug?: string;
  name?: string;
  width?: number;
  height?: number;
  initial_entities?: number;
  initial_organisms?: number;
  initial_resources?: number;
  food_energy?: number;
  food_sense_radius?: number;
  mutation_rate?: number;
  mutation_strength?: number;
  min_reproduction_age?: number;
  max_age?: number;
  visibility?: string;
};

function numberOrDefault(value: unknown, fallback: number) {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : fallback;
}

function stringOrDefault(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

export async function resetWorld(input: ResetWorldInput = {}) {
  const slug = stringOrDefault(input.slug, process.env.SQLIVE_WORLD_SLUG ?? "eldergrove");
  const name = stringOrDefault(input.name, "SQLife cloud experiment");

  if (!hasSupabaseConfig()) {
    return {
      ok: true,
      mode: "mock",
      world: {
        id: 0,
        slug,
        name,
      },
    };
  }

  const supabase = createSupabaseAdminClient().schema("alife");
  const { data, error } = await supabase.rpc("reset_world", {
    p_slug: slug,
    p_name: name,
    p_width: numberOrDefault(input.width, 60),
    p_height: numberOrDefault(input.height, 60),
    p_initial_entities: numberOrDefault(input.initial_entities ?? input.initial_organisms, 80),
    p_initial_resources: numberOrDefault(input.initial_resources, 350),
    p_food_energy: numberOrDefault(input.food_energy, 10.0),
    p_food_sense_radius: numberOrDefault(input.food_sense_radius, 6),
    p_mutation_rate: numberOrDefault(input.mutation_rate, 0.08),
    p_mutation_strength: numberOrDefault(input.mutation_strength, 0.12),
    p_min_reproduction_age: numberOrDefault(input.min_reproduction_age, 20),
    p_max_age: numberOrDefault(input.max_age, 220),
    p_visibility: stringOrDefault(input.visibility, "public"),
  });

  if (error) {
    throw new Error(error.message);
  }

  return {
    ok: true,
    mode: "supabase",
    world: {
      id: data as number,
      slug,
      name,
    },
  };
}
