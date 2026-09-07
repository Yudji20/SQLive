alter table alife.worlds
  add column if not exists food_target integer not null default 350,
  add column if not exists food_energy numeric(12,4) not null default 10.0,
  add column if not exists food_sense_radius integer not null default 6,
  add column if not exists mutation_rate numeric(9,6) not null default 0.080000,
  add column if not exists mutation_strength numeric(9,6) not null default 0.150000,
  add column if not exists min_reproduction_age integer not null default 20,
  add column if not exists max_age integer not null default 250;

alter table alife.worlds
  drop constraint if exists worlds_life_rules_check;

alter table alife.worlds
  add constraint worlds_life_rules_check check (
    food_target >= 0
    and food_energy > 0
    and food_sense_radius >= 0
    and mutation_rate >= 0
    and mutation_rate <= 1
    and mutation_strength >= 0
    and min_reproduction_age >= 0
    and max_age > 0
    and min_reproduction_age < max_age
  );

alter table alife.entities
  add column if not exists gene_strength numeric(10,4) not null default 1.0,
  add column if not exists gene_mass numeric(10,4) not null default 1.0;

alter table alife.entities
  drop constraint if exists entities_genes_check;

alter table alife.entities
  add constraint entities_genes_check check (
    gene_speed > 0
    and gene_metabolism > 0
    and gene_reproduction > 0
    and gene_aggression >= 0
    and gene_perception > 0
    and gene_magic_affinity >= 0
    and gene_cooperation >= 0
    and gene_strength > 0
    and gene_mass > 0
  );

alter table alife.world_metrics
  add column if not exists avg_gene_strength numeric(12,4),
  add column if not exists avg_gene_mass numeric(12,4);

create table if not exists alife.entity_history (
  history_id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  tick_no bigint not null,
  entity_id bigint not null,
  parent_entity_id bigint,
  generation integer not null,
  x integer not null,
  y integer not null,
  energy numeric(12,4) not null,
  health numeric(12,4) not null,
  age integer not null,
  gene_speed numeric(10,4) not null,
  gene_metabolism numeric(10,4) not null,
  gene_reproduction numeric(10,4) not null,
  gene_strength numeric(10,4) not null,
  gene_mass numeric(10,4) not null,
  alive boolean not null,
  created_at timestamptz not null default now()
);

create index if not exists entity_history_world_tick_idx
  on alife.entity_history (world_id, tick_no desc);

create index if not exists entity_history_world_generation_idx
  on alife.entity_history (world_id, generation);

alter table alife.entity_history enable row level security;

grant select on alife.entity_history to anon, authenticated;
grant usage, select on all sequences in schema alife to authenticated;
grant usage on schema alife to service_role;
grant all privileges on all tables in schema alife to service_role;
grant all privileges on all sequences in schema alife to service_role;
grant execute on all functions in schema alife to service_role;

alter default privileges in schema alife grant all privileges on tables to service_role;
alter default privileges in schema alife grant all privileges on sequences to service_role;
alter default privileges in schema alife grant execute on functions to service_role;

drop policy if exists entity_history_public_select on alife.entity_history;
create policy entity_history_public_select
on alife.entity_history
for select
to anon, authenticated
using (
  exists (
    select 1
    from alife.worlds w
    where w.id = entity_history.world_id
      and w.visibility = 'public'
  )
);

drop policy if exists entity_history_member_select on alife.entity_history;
create policy entity_history_member_select
on alife.entity_history
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = entity_history.world_id
      and wm.user_id = (select auth.uid())
  )
);

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
    avg_gene_cooperation,
    avg_gene_strength,
    avg_gene_mass
  )
  select
    p_world_id,
    v_tick_no,
    count(*)::integer,
    count(*) filter (where alive)::integer,
    coalesce((select count(*) from alife.resources where world_id = p_world_id and amount > 0), 0),
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
    avg(gene_cooperation) filter (where alive),
    avg(gene_strength) filter (where alive),
    avg(gene_mass) filter (where alive)
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
    avg_gene_strength = excluded.avg_gene_strength,
    avg_gene_mass = excluded.avg_gene_mass,
    created_at = now();
end;
$$;

create or replace function alife.reset_world(
  p_slug text default 'sqlife',
  p_name text default 'SQLife cloud experiment',
  p_width integer default 60,
  p_height integer default 60,
  p_initial_entities integer default 80,
  p_initial_resources integer default 350,
  p_food_energy numeric default 10.0,
  p_food_sense_radius integer default 6,
  p_mutation_rate numeric default 0.080000,
  p_mutation_strength numeric default 0.150000,
  p_min_reproduction_age integer default 20,
  p_max_age integer default 250,
  p_visibility text default 'public'
)
returns bigint
language plpgsql
as $$
declare
  v_world_id bigint;
  v_species_id bigint;
  v_faction_id bigint;
begin
  if p_width <= 0 or p_height <= 0 then
    raise exception 'World dimensions must be positive.';
  end if;
  if p_initial_entities < 0 or p_initial_resources < 0 then
    raise exception 'Initial counts cannot be negative.';
  end if;
  if p_food_energy <= 0 then
    raise exception 'Food energy must be positive.';
  end if;
  if p_food_sense_radius < 0 then
    raise exception 'Food sense radius cannot be negative.';
  end if;
  if p_mutation_rate < 0 or p_mutation_rate > 1 or p_mutation_strength < 0 then
    raise exception 'Invalid mutation parameters.';
  end if;
  if p_min_reproduction_age < 0 or p_max_age <= 0 or p_min_reproduction_age >= p_max_age then
    raise exception 'Invalid reproduction age parameters.';
  end if;

  delete from alife.worlds
  where slug = p_slug;

  insert into alife.worlds (
    slug,
    name,
    description,
    width,
    height,
    tick_no,
    status,
    visibility,
    food_target,
    food_energy,
    food_sense_radius,
    mutation_rate,
    mutation_strength,
    min_reproduction_age,
    max_age
  )
  values (
    p_slug,
    p_name,
    'SQLife selection experiment ported from SQL Server.',
    p_width,
    p_height,
    0,
    'paused',
    p_visibility,
    p_initial_resources,
    p_food_energy,
    p_food_sense_radius,
    p_mutation_rate,
    p_mutation_strength,
    p_min_reproduction_age,
    p_max_age
  )
  returning id into v_world_id;

  insert into alife.tiles (world_id, x, y, terrain_type, biome, fertility)
  select
    v_world_id,
    x,
    y,
    case
      when random() < 0.08 then 'water'
      when random() < 0.14 then 'mountain'
      when random() < 0.40 then 'forest'
      when random() < 0.45 then 'swamp'
      else 'plains'
    end,
    'temperate',
    round((0.75 + random() * 1.25)::numeric, 4)
  from generate_series(1, p_width) as x
  cross join generate_series(1, p_height) as y;

  insert into alife.species (world_id, key, name, category, diet, base_health, base_energy, base_traits)
  values (v_world_id, 'sqlife', 'SQLife Organism', 'creature', 'forager', 100, 30, '{"role":"organism"}'::jsonb)
  returning id into v_species_id;

  insert into alife.factions (world_id, key, name, alignment, color, traits)
  values (v_world_id, 'wild', 'Wild Organisms', 'wild', '#86d79b', '{"selection":"natural"}'::jsonb)
  returning id into v_faction_id;

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
    gene_strength,
    gene_mass,
    gene_aggression,
    gene_perception,
    gene_magic_affinity,
    gene_cooperation,
    born_tick,
    phenotype
  )
  select
    v_world_id,
    v_species_id,
    v_faction_id,
    0,
    1 + floor(random() * p_width)::integer,
    1 + floor(random() * p_height)::integer,
    100,
    round((20.0 + random() * 10.0)::numeric, 4),
    round((1.0 + random() * 3.0)::numeric, 4),
    round((0.5 + random() * 2.5)::numeric, 4),
    round((25.0 + random() * 25.0)::numeric, 4),
    round((0.5 + random() * 2.5)::numeric, 4),
    round((0.75 + random() * 1.75)::numeric, 4),
    round(random()::numeric, 4),
    greatest(1, p_food_sense_radius)::numeric,
    0,
    round(random()::numeric, 4),
    0,
    '{}'::jsonb
  from generate_series(1, p_initial_entities);

  insert into alife.resources (world_id, x, y, resource_key, amount, capacity, regen_rate)
  select
    v_world_id,
    1 + floor(random() * p_width)::integer,
    1 + floor(random() * p_height)::integer,
    'food',
    p_food_energy,
    p_food_energy,
    0
  from generate_series(1, p_initial_resources);

  insert into alife.event_log (world_id, tick_no, event_type, severity, title, description)
  values (
    v_world_id,
    0,
    'world_created',
    'notice',
    'World reset',
    'A SQLife experiment was seeded with mass, strength and food perception.'
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
  v_width integer;
  v_height integer;
  v_tick_no bigint;
  v_food_target integer;
  v_food_energy numeric;
  v_food_sense_radius integer;
  v_mutation_rate numeric;
  v_mutation_strength numeric;
  v_min_reproduction_age integer;
  v_max_age integer;
  v_current_resources integer;
  v_resources_to_spawn integer;
begin
  select
    width,
    height,
    tick_no + 1,
    food_target,
    food_energy,
    food_sense_radius,
    mutation_rate,
    mutation_strength,
    min_reproduction_age,
    max_age
  into
    v_width,
    v_height,
    v_tick_no,
    v_food_target,
    v_food_energy,
    v_food_sense_radius,
    v_mutation_rate,
    v_mutation_strength,
    v_min_reproduction_age,
    v_max_age
  from alife.worlds
  where id = p_world_id;

  if v_width is null then
    raise exception 'World % not found', p_world_id;
  end if;

  update alife.worlds
  set tick_no = v_tick_no
  where id = p_world_id;

  update alife.entities
  set
    age = age + 1,
    energy = greatest(
      0,
      energy
        - gene_metabolism
        - case when gene_speed > 1.0 then (gene_speed - 1.0) * 0.05 else 0 end
        - case when gene_mass > 1.0 then (gene_mass - 1.0) * 0.08 else 0 end
    ),
    updated_at = now()
  where world_id = p_world_id
    and alive;

  with move_plans as (
    select
      e.id,
      least(v_width, greatest(1, e.x + move.dx)) as next_x,
      least(v_height, greatest(1, e.y + move.dy)) as next_y
    from alife.entities as e
    cross join lateral (
      select (
        1.0
        + case when e.gene_mass > 1.0 then (e.gene_mass - 1.0) * 0.35 else 0 end
        + case when e.gene_strength > 1.0 then (e.gene_strength - 1.0) * 0.10 else 0 end
      ) as drag_factor
    ) as drag
    cross join lateral (
      select greatest(1, round(e.gene_speed / drag.drag_factor)::integer) as speed
    ) as speed
    left join lateral (
      select r.x as target_x, r.y as target_y
      from alife.resources as r
      where r.world_id = e.world_id
        and r.amount > 0
        and abs(r.x - e.x) + abs(r.y - e.y) <= v_food_sense_radius
      order by abs(r.x - e.x) + abs(r.y - e.y), random()
      limit 1
    ) as target on true
    cross join lateral (
      select
        case
          when target.target_x is null then floor(random() * (2 * speed.speed + 1))::integer - speed.speed
          when target.target_x > e.x then least(speed.speed, target.target_x - e.x)
          when target.target_x < e.x then -least(speed.speed, e.x - target.target_x)
          else 0
        end as dx,
        case
          when target.target_y is null then floor(random() * (2 * speed.speed + 1))::integer - speed.speed
          when target.target_y > e.y then least(speed.speed, target.target_y - e.y)
          when target.target_y < e.y then -least(speed.speed, e.y - target.target_y)
          else 0
        end as dy
    ) as move
    where e.world_id = p_world_id
      and e.alive
  )
  update alife.entities as e
  set
    x = move_plans.next_x,
    y = move_plans.next_y,
    updated_at = now()
  from move_plans
  where e.id = move_plans.id;

  with contenders as (
    select
      e.id as entity_id,
      r.id as resource_id,
      r.amount as energy,
      row_number() over (
        partition by r.id
        order by e.gene_strength * e.gene_mass * random() desc, e.energy desc, e.id
      ) as contender_rank
    from alife.entities as e
    join alife.resources as r
      on r.world_id = e.world_id
     and r.x = e.x
     and r.y = e.y
     and r.amount > 0
    where e.world_id = p_world_id
      and e.alive
  ),
  resource_winners as (
    select entity_id, resource_id, energy
    from contenders
    where contender_rank = 1
  ),
  meals as (
    select entity_id, resource_id, energy
    from (
      select
        entity_id,
        resource_id,
        energy,
        row_number() over (partition by entity_id order by energy desc, resource_id) as entity_resource_rank
      from resource_winners
    ) ranked
    where entity_resource_rank = 1
  ),
  fed as (
    update alife.entities as e
    set
      energy = e.energy + meals.energy,
      updated_at = now()
    from meals
    where e.id = meals.entity_id
    returning meals.resource_id
  )
  delete from alife.resources as r
  using fed
  where r.id = fed.resource_id;

  with parents as (
    select *
    from alife.entities
    where world_id = p_world_id
      and alive
      and age >= v_min_reproduction_age
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
      gene_strength,
      gene_mass,
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
      least(v_width, greatest(1, p.x + floor(random() * 3)::integer - 1)),
      least(v_height, greatest(1, p.y + floor(random() * 3)::integer - 1)),
      p.health,
      p.energy / 2.0,
      case when random() < v_mutation_rate then greatest(0.1, p.gene_speed * (1 + ((random() * 2 - 1) * v_mutation_strength))) else p.gene_speed end,
      case when random() < v_mutation_rate then greatest(0.1, p.gene_metabolism * (1 + ((random() * 2 - 1) * v_mutation_strength))) else p.gene_metabolism end,
      case when random() < v_mutation_rate then greatest(1.0, p.gene_reproduction * (1 + ((random() * 2 - 1) * v_mutation_strength))) else p.gene_reproduction end,
      case when random() < v_mutation_rate then greatest(0.1, p.gene_strength * (1 + ((random() * 2 - 1) * v_mutation_strength))) else p.gene_strength end,
      case when random() < v_mutation_rate then greatest(0.25, p.gene_mass * (1 + ((random() * 2 - 1) * v_mutation_strength))) else p.gene_mass end,
      p.gene_aggression,
      p.gene_perception,
      p.gene_magic_affinity,
      p.gene_cooperation,
      v_tick_no,
      p.phenotype
    from parents as p
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

  update alife.entities as e
  set
    energy = e.energy / 2.0,
    updated_at = now()
  where e.world_id = p_world_id
    and e.alive
    and e.age >= v_min_reproduction_age
    and e.energy >= e.gene_reproduction;

  with deaths as (
    update alife.entities
    set
      alive = false,
      died_tick = v_tick_no,
      updated_at = now()
    where world_id = p_world_id
      and alive
      and (energy <= 0 or health <= 0 or age >= v_max_age)
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

  select count(*)::integer
  into v_current_resources
  from alife.resources
  where world_id = p_world_id
    and amount > 0;

  v_resources_to_spawn := greatest(0, v_food_target - v_current_resources);

  insert into alife.resources (world_id, x, y, resource_key, amount, capacity, regen_rate)
  select
    p_world_id,
    1 + floor(random() * v_width)::integer,
    1 + floor(random() * v_height)::integer,
    'food',
    v_food_energy,
    v_food_energy,
    0
  from generate_series(1, v_resources_to_spawn);

  insert into alife.entity_history (
    world_id,
    tick_no,
    entity_id,
    parent_entity_id,
    generation,
    x,
    y,
    energy,
    health,
    age,
    gene_speed,
    gene_metabolism,
    gene_reproduction,
    gene_strength,
    gene_mass,
    alive
  )
  select
    world_id,
    v_tick_no,
    id,
    parent_entity_id,
    generation,
    x,
    y,
    energy,
    health,
    age,
    gene_speed,
    gene_metabolism,
    gene_reproduction,
    gene_strength,
    gene_mass,
    alive
  from alife.entities
  where world_id = p_world_id;

  perform alife.capture_metrics(p_world_id);

  return v_tick_no;
end;
$$;

create or replace function alife.run_world(
  p_world_id bigint,
  p_ticks integer default 100
)
returns bigint
language plpgsql
as $$
declare
  v_index integer := 0;
  v_tick_no bigint;
begin
  if p_ticks < 0 then
    raise exception 'Ticks cannot be negative.';
  end if;

  while v_index < p_ticks loop
    v_tick_no := alife.execute_world_tick(p_world_id);
    v_index := v_index + 1;
  end loop;

  return coalesce(v_tick_no, (select tick_no from alife.worlds where id = p_world_id));
end;
$$;

alter function alife.set_updated_at() set search_path = '';
alter function alife.capture_metrics(bigint) set search_path = '';
alter function alife.create_demo_world(text, text, integer, integer, integer) set search_path = '';
alter function alife.apply_admin_actions(bigint, bigint) set search_path = '';
alter function alife.execute_world_tick(bigint) set search_path = '';
alter function alife.reset_world(text, text, integer, integer, integer, integer, numeric, integer, numeric, numeric, integer, integer, text) set search_path = '';
alter function alife.execute_tick(bigint) set search_path = '';
alter function alife.run_world(bigint, integer) set search_path = '';

drop view if exists alife.v_world_overview;

create view alife.v_world_overview
with (security_invoker = true)
as
select
  w.id as world_id,
  w.slug,
  w.name,
  w.width,
  w.height,
  w.tick_no,
  w.status,
  w.food_target,
  w.food_energy,
  w.food_sense_radius,
  w.min_reproduction_age,
  w.max_age,
  coalesce(m.alive_entities, 0) as alive_entities,
  coalesce(m.resource_total, 0) as resource_total,
  m.avg_energy,
  m.avg_health,
  m.avg_age,
  m.avg_generation,
  m.avg_gene_speed,
  m.avg_gene_metabolism,
  m.avg_gene_reproduction,
  m.avg_gene_strength,
  m.avg_gene_mass,
  w.updated_at
from alife.worlds as w
left join lateral (
  select *
  from alife.world_metrics as wm
  where wm.world_id = w.id
  order by wm.tick_no desc
  limit 1
) as m on true;

grant select on alife.v_world_overview to anon, authenticated;
