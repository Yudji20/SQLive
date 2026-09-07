select alife.create_demo_world(
  p_slug => 'eldergrove',
  p_name => 'Eldergrove',
  p_width => 40,
  p_height => 30,
  p_initial_entities => 80
) as world_id;

select alife.execute_world_tick(id) as tick_no
from alife.worlds
where slug = 'eldergrove';

select *
from alife.v_world_overview
where slug = 'eldergrove';

select tick_no, population, alive_entities, resource_total, avg_energy, avg_generation
from alife.world_metrics
where world_id = (select id from alife.worlds where slug = 'eldergrove')
order by tick_no desc
limit 10;

select tick_no, event_type, title, description
from alife.event_log
where world_id = (select id from alife.worlds where slug = 'eldergrove')
order by tick_no desc, id desc
limit 20;
