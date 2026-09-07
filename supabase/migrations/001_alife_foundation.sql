create schema if not exists alife;

create table if not exists alife.worlds (
  id bigint generated always as identity primary key,
  slug text not null unique,
  name text not null,
  description text,
  width integer not null,
  height integer not null,
  tick_no bigint not null default 0,
  tick_interval_seconds integer not null default 60,
  status text not null default 'paused',
  seed bigint,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint worlds_size_check check (width > 0 and height > 0),
  constraint worlds_tick_interval_check check (tick_interval_seconds > 0),
  constraint worlds_status_check check (status in ('paused', 'running', 'archived'))
);

create or replace function alife.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists alife.tiles (
  world_id bigint not null references alife.worlds(id) on delete cascade,
  x integer not null,
  y integer not null,
  terrain_type text not null default 'plains',
  biome text not null default 'temperate',
  elevation numeric(8,4) not null default 0,
  moisture numeric(8,4) not null default 0,
  fertility numeric(8,4) not null default 1,
  mana numeric(8,4) not null default 0,
  discovered boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (world_id, x, y),
  constraint tiles_position_check check (x >= 1 and y >= 1),
  constraint tiles_terrain_type_check check
    (terrain_type in ('plains', 'forest', 'mountain', 'water', 'swamp', 'desert', 'ruins')),
  constraint tiles_biome_check check
    (biome in ('temperate', 'boreal', 'tropical', 'arid', 'arcane', 'deadlands'))
);

create table if not exists alife.species (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  key text not null,
  name text not null,
  category text not null default 'creature',
  diet text not null default 'forager',
  base_health numeric(12,4) not null default 100,
  base_energy numeric(12,4) not null default 30,
  base_traits jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint species_world_id_id_unique unique (world_id, id),
  constraint species_key_unique unique (world_id, key),
  constraint species_category_check check
    (category in ('creature', 'person', 'spirit', 'monster', 'plant', 'construct')),
  constraint species_diet_check check
    (diet in ('forager', 'herbivore', 'carnivore', 'omnivore', 'arcane', 'none')),
  constraint species_base_stats_check check (base_health > 0 and base_energy >= 0)
);

create table if not exists alife.factions (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  key text not null,
  name text not null,
  alignment text not null default 'neutral',
  color text not null default '#64748b',
  home_x integer,
  home_y integer,
  traits jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint factions_world_id_id_unique unique (world_id, id),
  constraint factions_key_unique unique (world_id, key),
  constraint factions_alignment_check check
    (alignment in ('lawful', 'neutral', 'chaotic', 'wild', 'hostile')),
  constraint factions_home_check check
    ((home_x is null and home_y is null) or (home_x >= 1 and home_y >= 1))
);

create table if not exists alife.entities (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  species_id bigint not null,
  faction_id bigint,
  parent_entity_id bigint,
  name text,
  generation integer not null default 0,
  x integer not null,
  y integer not null,
  health numeric(12,4) not null,
  energy numeric(12,4) not null,
  age integer not null default 0,
  gene_speed numeric(10,4) not null default 1,
  gene_metabolism numeric(10,4) not null default 1,
  gene_reproduction numeric(10,4) not null default 30,
  gene_aggression numeric(10,4) not null default 0.5,
  gene_perception numeric(10,4) not null default 1,
  gene_magic_affinity numeric(10,4) not null default 0,
  gene_cooperation numeric(10,4) not null default 0.5,
  alive boolean not null default true,
  born_tick bigint not null default 0,
  died_tick bigint,
  phenotype jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint entities_world_id_id_unique unique (world_id, id),
  constraint entities_tile_fk foreign key (world_id, x, y)
    references alife.tiles (world_id, x, y),
  constraint entities_species_fk foreign key (world_id, species_id)
    references alife.species (world_id, id),
  constraint entities_faction_fk foreign key (world_id, faction_id)
    references alife.factions (world_id, id),
  constraint entities_parent_fk foreign key (world_id, parent_entity_id)
    references alife.entities (world_id, id),
  constraint entities_generation_check check (generation >= 0),
  constraint entities_position_check check (x >= 1 and y >= 1),
  constraint entities_age_check check (age >= 0),
  constraint entities_energy_check check (energy >= 0),
  constraint entities_health_check check (health >= 0),
  constraint entities_genes_check check
    (
      gene_speed > 0
      and gene_metabolism > 0
      and gene_reproduction > 0
      and gene_aggression >= 0
      and gene_perception > 0
      and gene_magic_affinity >= 0
      and gene_cooperation >= 0
    )
);

create table if not exists alife.resources (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  x integer not null,
  y integer not null,
  resource_key text not null,
  amount numeric(12,4) not null,
  capacity numeric(12,4) not null,
  regen_rate numeric(12,4) not null default 0,
  updated_at timestamptz not null default now(),
  constraint resources_tile_fk foreign key (world_id, x, y)
    references alife.tiles (world_id, x, y) on delete cascade,
  constraint resources_position_check check (x >= 1 and y >= 1),
  constraint resources_amount_check check (amount >= 0),
  constraint resources_capacity_check check (capacity >= 0),
  constraint resources_regen_rate_check check (regen_rate >= 0),
  constraint resources_amount_capacity_check check (amount <= capacity)
);

create table if not exists alife.agent_brains (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  entity_id bigint unique,
  parent_brain_id bigint,
  brain_type text not null default 'feed_forward',
  input_count integer not null,
  hidden_count integer not null default 0,
  output_count integer not null,
  generation integer not null default 0,
  mutation_rate numeric(8,6) not null default 0.05,
  mutation_strength numeric(8,6) not null default 0.10,
  created_at timestamptz not null default now(),
  constraint agent_brains_world_id_id_unique unique (world_id, id),
  constraint agent_brains_entity_fk foreign key (world_id, entity_id)
    references alife.entities (world_id, id) on delete cascade,
  constraint agent_brains_parent_fk foreign key (world_id, parent_brain_id)
    references alife.agent_brains (world_id, id),
  constraint agent_brains_type_check check (brain_type in ('feed_forward', 'rule_based', 'random')),
  constraint agent_brains_shape_check check (input_count > 0 and hidden_count >= 0 and output_count > 0),
  constraint agent_brains_generation_check check (generation >= 0),
  constraint agent_brains_mutation_check check
    (mutation_rate >= 0 and mutation_rate <= 1 and mutation_strength >= 0)
);

create table if not exists alife.brain_weights (
  id bigint generated always as identity primary key,
  brain_id bigint not null references alife.agent_brains(id) on delete cascade,
  layer_no integer not null,
  from_node integer not null,
  to_node integer not null,
  weight double precision not null,
  bias double precision not null default 0,
  constraint brain_weights_node_check check (layer_no >= 0 and from_node >= 0 and to_node >= 0),
  constraint brain_weights_unique unique (brain_id, layer_no, from_node, to_node)
);

create table if not exists alife.action_queue (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  tick_no bigint not null,
  entity_id bigint,
  action_type text not null,
  payload jsonb not null default '{}'::jsonb,
  source text not null default 'brain',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint action_queue_entity_fk foreign key (world_id, entity_id)
    references alife.entities (world_id, id) on delete cascade,
  constraint action_queue_source_check check (source in ('brain', 'rule', 'admin', 'system')),
  constraint action_queue_status_check check (status in ('pending', 'applied', 'rejected'))
);

create table if not exists alife.admin_actions (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  created_by uuid,
  action_type text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  requested_at timestamptz not null default now(),
  applied_tick bigint,
  applied_at timestamptz,
  result jsonb,
  constraint admin_actions_status_check check (status in ('pending', 'applied', 'rejected', 'cancelled'))
);

create table if not exists alife.event_log (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  tick_no bigint not null,
  event_type text not null,
  severity text not null default 'info',
  entity_id bigint,
  target_entity_id bigint,
  x integer,
  y integer,
  title text not null,
  description text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint event_log_entity_fk foreign key (world_id, entity_id)
    references alife.entities (world_id, id),
  constraint event_log_target_entity_fk foreign key (world_id, target_entity_id)
    references alife.entities (world_id, id),
  constraint event_log_severity_check check (severity in ('debug', 'info', 'notice', 'warning', 'critical'))
);

create table if not exists alife.decision_log (
  id bigint generated always as identity primary key,
  world_id bigint not null references alife.worlds(id) on delete cascade,
  tick_no bigint not null,
  entity_id bigint,
  brain_id bigint,
  observation jsonb not null,
  outputs jsonb not null default '{}'::jsonb,
  selected_action text not null,
  created_at timestamptz not null default now(),
  constraint decision_log_entity_fk foreign key (world_id, entity_id)
    references alife.entities (world_id, id) on delete cascade,
  constraint decision_log_brain_fk foreign key (world_id, brain_id)
    references alife.agent_brains (world_id, id)
);

create table if not exists alife.world_metrics (
  world_id bigint not null references alife.worlds(id) on delete cascade,
  tick_no bigint not null,
  population integer not null,
  alive_entities integer not null,
  resource_total numeric(14,4) not null,
  avg_energy numeric(12,4),
  avg_health numeric(12,4),
  avg_age numeric(12,4),
  avg_generation numeric(12,4),
  avg_gene_speed numeric(12,4),
  avg_gene_metabolism numeric(12,4),
  avg_gene_reproduction numeric(12,4),
  avg_gene_aggression numeric(12,4),
  avg_gene_perception numeric(12,4),
  avg_gene_magic_affinity numeric(12,4),
  avg_gene_cooperation numeric(12,4),
  created_at timestamptz not null default now(),
  primary key (world_id, tick_no)
);

create index if not exists tiles_world_biome_idx
  on alife.tiles (world_id, biome, terrain_type);

create index if not exists species_world_id_idx
  on alife.species (world_id);

create index if not exists factions_world_id_idx
  on alife.factions (world_id);

create index if not exists entities_world_alive_position_idx
  on alife.entities (world_id, alive, x, y);

create index if not exists entities_species_id_idx
  on alife.entities (species_id);

create index if not exists entities_faction_id_idx
  on alife.entities (faction_id);

create index if not exists entities_parent_entity_id_idx
  on alife.entities (parent_entity_id);

create index if not exists resources_world_position_idx
  on alife.resources (world_id, x, y);

create index if not exists agent_brains_world_id_idx
  on alife.agent_brains (world_id);

create index if not exists agent_brains_parent_brain_id_idx
  on alife.agent_brains (parent_brain_id);

create index if not exists brain_weights_brain_id_idx
  on alife.brain_weights (brain_id);

create index if not exists action_queue_world_status_tick_idx
  on alife.action_queue (world_id, status, tick_no);

create index if not exists action_queue_entity_id_idx
  on alife.action_queue (entity_id);

create index if not exists admin_actions_world_status_idx
  on alife.admin_actions (world_id, status, requested_at);

create index if not exists event_log_world_tick_idx
  on alife.event_log (world_id, tick_no desc, id desc);

create index if not exists event_log_entity_id_idx
  on alife.event_log (entity_id);

create index if not exists decision_log_world_tick_idx
  on alife.decision_log (world_id, tick_no desc);

create index if not exists decision_log_entity_id_idx
  on alife.decision_log (entity_id);

drop trigger if exists worlds_set_updated_at on alife.worlds;
create trigger worlds_set_updated_at
before update on alife.worlds
for each row execute function alife.set_updated_at();

drop trigger if exists tiles_set_updated_at on alife.tiles;
create trigger tiles_set_updated_at
before update on alife.tiles
for each row execute function alife.set_updated_at();

drop trigger if exists entities_set_updated_at on alife.entities;
create trigger entities_set_updated_at
before update on alife.entities
for each row execute function alife.set_updated_at();

drop trigger if exists resources_set_updated_at on alife.resources;
create trigger resources_set_updated_at
before update on alife.resources
for each row execute function alife.set_updated_at();

alter table alife.worlds enable row level security;
alter table alife.tiles enable row level security;
alter table alife.species enable row level security;
alter table alife.factions enable row level security;
alter table alife.entities enable row level security;
alter table alife.resources enable row level security;
alter table alife.agent_brains enable row level security;
alter table alife.brain_weights enable row level security;
alter table alife.action_queue enable row level security;
alter table alife.admin_actions enable row level security;
alter table alife.event_log enable row level security;
alter table alife.decision_log enable row level security;
alter table alife.world_metrics enable row level security;

create or replace view alife.v_world_overview
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
  coalesce(m.alive_entities, 0) as alive_entities,
  coalesce(m.resource_total, 0) as resource_total,
  m.avg_energy,
  m.avg_health,
  m.avg_age,
  m.avg_generation,
  w.updated_at
from alife.worlds as w
left join lateral (
  select *
  from alife.world_metrics as wm
  where wm.world_id = w.id
  order by wm.tick_no desc
  limit 1
) as m on true;
