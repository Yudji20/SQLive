create index if not exists entities_alive_world_id_idx
  on alife.entities (world_id, id)
  where alive;

create index if not exists entities_alive_generation_energy_idx
  on alife.entities (world_id, generation desc, energy desc, id)
  where alive;

create index if not exists entities_alive_energy_age_idx
  on alife.entities (world_id, energy desc, age, id)
  where alive;

create index if not exists resources_active_world_position_idx
  on alife.resources (world_id, x, y, id)
  where amount > 0;

create index if not exists resources_active_world_id_idx
  on alife.resources (world_id, id)
  where amount > 0;

create index if not exists event_log_world_tick_id_idx
  on alife.event_log (world_id, tick_no desc, id desc);

analyze alife.worlds;
analyze alife.entities;
analyze alife.resources;
analyze alife.world_metrics;
analyze alife.event_log;
analyze alife.entity_history;
