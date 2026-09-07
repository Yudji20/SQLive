create or replace function alife.capture_metrics(p_world_id bigint)
returns void
language plpgsql
as $$
declare
  v_tick_no bigint;
begin
  select tick_no
  into v_tick_no
  from alife.worlds
  where id = p_world_id;

  if v_tick_no is null then
    raise exception 'World % not found', p_world_id;
  end if;

  insert into alife.world_metrics (
    world_id,
    tick_no,
    population,
    alive_entities,
    resource_total,
    avg_energy,
    avg_health,
    avg_age,
    avg_generation,
    avg_gene_speed,
    avg_gene_metabolism,
    avg_gene_reproduction,
    avg_gene_aggression,
    avg_gene_perception,
    avg_gene_magic_affinity,
    avg_gene_cooperation
  )
  select
    p_world_id,
    v_tick_no,
    count(*)::integer,
    count(*) filter (where alive)::integer,
    coalesce((select sum(amount) from alife.resources where world_id = p_world_id), 0),
    avg(energy) filter (where alive),
    avg(health) filter (where alive),
    avg(age) filter (where alive),
    avg(generation) filter (where alive),
    avg(gene_speed) filter (where alive),
    avg(gene_metabolism) filter (where alive),
    avg(gene_reproduction) filter (where alive),
    avg(gene_aggression) filter (where alive),
    avg(gene_perception) filter (where alive),
    avg(gene_magic_affinity) filter (where alive),
    avg(gene_cooperation) filter (where alive)
  from alife.entities
  where world_id = p_world_id
  on conflict (world_id, tick_no) do update
  set
    population = excluded.population,
    alive_entities = excluded.alive_entities,
    resource_total = excluded.resource_total,
    avg_energy = excluded.avg_energy,
    avg_health = excluded.avg_health,
    avg_age = excluded.avg_age,
    avg_generation = excluded.avg_generation,
    avg_gene_speed = excluded.avg_gene_speed,
    avg_gene_metabolism = excluded.avg_gene_metabolism,
    avg_gene_reproduction = excluded.avg_gene_reproduction,
    avg_gene_aggression = excluded.avg_gene_aggression,
    avg_gene_perception = excluded.avg_gene_perception,
    avg_gene_magic_affinity = excluded.avg_gene_magic_affinity,
    avg_gene_cooperation = excluded.avg_gene_cooperation,
    created_at = now();
end;
$$;

create or replace function alife.create_demo_world(
  p_slug text default 'eldergrove',
  p_name text default 'Eldergrove',
  p_width integer default 40,
  p_height integer default 30,
  p_initial_entities integer default 80
)
returns bigint
language plpgsql
as $$
declare
  v_world_id bigint;
  v_species_forager bigint;
  v_species_wolf bigint;
  v_species_sprite bigint;
  v_faction_wild bigint;
  v_faction_grove bigint;
begin
  select id
  into v_world_id
  from alife.worlds
  where slug = p_slug;

  if v_world_id is not null then
    return v_world_id;
  end if;

  insert into alife.worlds (slug, name, description, width, height, status)
  values (
    p_slug,
    p_name,
    'A small fantasy ecosystem for neuroevolution experiments.',
    p_width,
    p_height,
    'paused'
  )
  returning id into v_world_id;

  insert into alife.tiles (
    world_id,
    x,
    y,
    terrain_type,
    biome,
    elevation,
    moisture,
    fertility,
    mana
  )
  select
    v_world_id,
    x,
    y,
    case
      when random() < 0.08 then 'water'
      when random() < 0.18 then 'mountain'
      when random() < 0.42 then 'forest'
      when random() < 0.48 then 'ruins'
      else 'plains'
    end,
    case
      when random() < 0.10 then 'arcane'
      when random() < 0.18 then 'boreal'
      when random() < 0.24 then 'deadlands'
      else 'temperate'
    end,
    round((random() * 2)::numeric, 4),
    round(random()::numeric, 4),
    round((0.5 + random() * 1.5)::numeric, 4),
    round((random() * 2)::numeric, 4)
  from generate_series(1, p_width) as x
  cross join generate_series(1, p_height) as y;

  insert into alife.species (world_id, key, name, category, diet, base_health, base_energy, base_traits)
  values
    (v_world_id, 'mossling', 'Mossling', 'creature', 'forager', 40, 26, '{"role":"gatherer"}'),
    (v_world_id, 'ash_wolf', 'Ash Wolf', 'monster', 'carnivore', 70, 34, '{"role":"predator"}'),
    (v_world_id, 'glimmer_sprite', 'Glimmer Sprite', 'spirit', 'arcane', 30, 38, '{"role":"wanderer"}');

  select id into v_species_forager from alife.species where world_id = v_world_id and key = 'mossling';
  select id into v_species_wolf from alife.species where world_id = v_world_id and key = 'ash_wolf';
  select id into v_species_sprite from alife.species where world_id = v_world_id and key = 'glimmer_sprite';

  insert into alife.factions (world_id, key, name, alignment, color, home_x, home_y, traits)
  values
    (v_world_id, 'wild', 'The Wild', 'wild', '#16a34a', 5, 5, '{"instinctive":true}'),
    (v_world_id, 'grove_court', 'Grove Court', 'neutral', '#22c55e', p_width / 2, p_height / 2, '{"diplomatic":true}');

  select id into v_faction_wild from alife.factions where world_id = v_world_id and key = 'wild';
  select id into v_faction_grove from alife.factions where world_id = v_world_id and key = 'grove_court';

  insert into alife.resources (world_id, x, y, resource_key, amount, capacity, regen_rate)
  select
    v_world_id,
    t.x,
    t.y,
    case when t.biome = 'arcane' then 'mana_bloom' else 'food' end,
    round((5 + random() * 20)::numeric, 4),
    30,
    round((0.5 + random() * 1.5)::numeric, 4)
  from alife.tiles as t
  where t.world_id = v_world_id
    and t.terrain_type <> 'water'
    and random() < 0.22;

  insert into alife.entities (
    world_id,
    species_id,
    faction_id,
    generation,
    x,
    y,
    health,
    energy,
    gene_speed,
    gene_metabolism,
    gene_reproduction,
    gene_aggression,
    gene_perception,
    gene_magic_affinity,
    gene_cooperation,
    phenotype
  )
  select
    v_world_id,
    case
      when rn % 10 = 0 then v_species_wolf
      when rn % 7 = 0 then v_species_sprite
      else v_species_forager
    end,
    case
      when rn % 7 = 0 then v_faction_grove
      else v_faction_wild
    end,
    0,
    t.x,
    t.y,
    case
      when rn % 10 = 0 then 70
      when rn % 7 = 0 then 30
      else 40
    end,
    round((20 + random() * 20)::numeric, 4),
    round((1 + random() * 3)::numeric, 4),
    round((0.4 + random() * 1.8)::numeric, 4),
    round((22 + random() * 26)::numeric, 4),
    round(random()::numeric, 4),
    round((1 + random() * 4)::numeric, 4),
    round(random()::numeric, 4),
    round(random()::numeric, 4),
    '{}'::jsonb
  from (
    select row_number() over () as rn, x, y
    from alife.tiles
    where world_id = v_world_id
      and terrain_type <> 'water'
    order by random()
    limit p_initial_entities
  ) as t;

  insert into alife.event_log (world_id, tick_no, event_type, severity, title, description)
  values (
    v_world_id,
    0,
    'world_created',
    'notice',
    'World awakened',
    'The first version of the fantasy ecosystem was seeded.'
  );

  perform alife.capture_metrics(v_world_id);

  return v_world_id;
end;
$$;

create or replace function alife.execute_tick(p_world_id bigint)
returns bigint
language plpgsql
as $$
declare
  v_tick_no bigint;
begin
  update alife.worlds
  set tick_no = tick_no + 1
  where id = p_world_id
  returning tick_no into v_tick_no;

  if v_tick_no is null then
    raise exception 'World % not found', p_world_id;
  end if;

  update alife.entities
  set
    age = age + 1,
    energy = greatest(0, energy - gene_metabolism),
    updated_at = now()
  where world_id = p_world_id
    and alive;

  update alife.entities as e
  set
    x = least(w.width, greatest(1, e.x + floor(random() * (2 * ceil(e.gene_speed)::integer + 1))::integer - ceil(e.gene_speed)::integer)),
    y = least(w.height, greatest(1, e.y + floor(random() * (2 * ceil(e.gene_speed)::integer + 1))::integer - ceil(e.gene_speed)::integer)),
    updated_at = now()
  from alife.worlds as w
  where w.id = e.world_id
    and e.world_id = p_world_id
    and e.alive;

  with meals as (
    select distinct on (e.id)
      e.id as entity_id,
      r.id as resource_id,
      least(r.amount, 10) as eaten
    from alife.entities as e
    join alife.resources as r
      on r.world_id = e.world_id
     and r.x = e.x
     and r.y = e.y
     and r.amount > 0
    where e.world_id = p_world_id
      and e.alive
    order by e.id, r.amount desc
  ),
  fed as (
    update alife.entities as e
    set
      energy = e.energy + meals.eaten,
      updated_at = now()
    from meals
    where e.id = meals.entity_id
    returning meals.resource_id, meals.eaten
  )
  update alife.resources as r
  set
    amount = greatest(0, r.amount - fed.eaten),
    updated_at = now()
  from fed
  where r.id = fed.resource_id;

  with parents as (
    select *
    from alife.entities
    where world_id = p_world_id
      and alive
      and energy >= gene_reproduction
  ),
  births as (
    insert into alife.entities (
      world_id,
      species_id,
      faction_id,
      parent_entity_id,
      generation,
      x,
      y,
      health,
      energy,
      gene_speed,
      gene_metabolism,
      gene_reproduction,
      gene_aggression,
      gene_perception,
      gene_magic_affinity,
      gene_cooperation,
      born_tick,
      phenotype
    )
    select
      p.world_id,
      p.species_id,
      p.faction_id,
      p.id,
      p.generation + 1,
      least(w.width, greatest(1, p.x + floor(random() * 3)::integer - 1)),
      least(w.height, greatest(1, p.y + floor(random() * 3)::integer - 1)),
      p.health,
      p.energy / 2,
      greatest(0.1, p.gene_speed * (1 + ((random() * 2 - 1) * 0.08))),
      greatest(0.1, p.gene_metabolism * (1 + ((random() * 2 - 1) * 0.08))),
      greatest(1, p.gene_reproduction * (1 + ((random() * 2 - 1) * 0.08))),
      greatest(0, p.gene_aggression * (1 + ((random() * 2 - 1) * 0.08))),
      greatest(0.1, p.gene_perception * (1 + ((random() * 2 - 1) * 0.08))),
      greatest(0, p.gene_magic_affinity * (1 + ((random() * 2 - 1) * 0.08))),
      greatest(0, p.gene_cooperation * (1 + ((random() * 2 - 1) * 0.08))),
      v_tick_no,
      p.phenotype
    from parents as p
    join alife.worlds as w on w.id = p.world_id
    returning id, world_id, parent_entity_id, x, y
  )
  insert into alife.event_log (world_id, tick_no, event_type, severity, entity_id, target_entity_id, x, y, title)
  select
    world_id,
    v_tick_no,
    'birth',
    'info',
    parent_entity_id,
    id,
    x,
    y,
    'A new life emerged'
  from births;

  update alife.entities
  set
    energy = energy / 2,
    updated_at = now()
  where world_id = p_world_id
    and alive
    and born_tick < v_tick_no
    and energy >= gene_reproduction;

  with deaths as (
    update alife.entities
    set
      alive = false,
      died_tick = v_tick_no,
      updated_at = now()
    where world_id = p_world_id
      and alive
      and (energy <= 0 or health <= 0 or age >= 300)
    returning id, world_id, x, y
  )
  insert into alife.event_log (world_id, tick_no, event_type, severity, entity_id, x, y, title)
  select
    world_id,
    v_tick_no,
    'death',
    'notice',
    id,
    x,
    y,
    'A life ended'
  from deaths;

  update alife.resources as r
  set
    amount = least(capacity, amount + regen_rate),
    updated_at = now()
  where r.world_id = p_world_id;

  perform alife.capture_metrics(p_world_id);

  return v_tick_no;
end;
$$;
