create or replace function alife.apply_admin_actions(
  p_world_id bigint,
  p_tick_no bigint
)
returns integer
language plpgsql
as $$
declare
  v_action record;
  v_species_id bigint;
  v_faction_id bigint;
  v_entity_id bigint;
  v_applied integer := 0;
begin
  for v_action in
    select *
    from alife.admin_actions
    where world_id = p_world_id
      and status = 'pending'
    order by requested_at, id
    for update skip locked
  loop
    begin
      if v_action.action_type = 'spawn_entity' then
        select id
        into v_species_id
        from alife.species
        where world_id = p_world_id
          and key = v_action.payload->>'species_key';

        if v_species_id is null then
          raise exception 'Unknown species %', v_action.payload->>'species_key';
        end if;

        select id
        into v_faction_id
        from alife.factions
        where world_id = p_world_id
          and key = coalesce(v_action.payload->>'faction_key', 'wild');

        insert into alife.entities (
          world_id,
          species_id,
          faction_id,
          name,
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
        values (
          p_world_id,
          v_species_id,
          v_faction_id,
          nullif(v_action.payload->>'name', ''),
          0,
          (v_action.payload->>'x')::integer,
          (v_action.payload->>'y')::integer,
          coalesce((v_action.payload->>'health')::numeric, 80),
          coalesce((v_action.payload->>'energy')::numeric, 40),
          coalesce((v_action.payload->>'gene_speed')::numeric, 2),
          coalesce((v_action.payload->>'gene_metabolism')::numeric, 1),
          coalesce((v_action.payload->>'gene_reproduction')::numeric, 30),
          coalesce((v_action.payload->>'gene_aggression')::numeric, 0.5),
          coalesce((v_action.payload->>'gene_perception')::numeric, 2),
          coalesce((v_action.payload->>'gene_magic_affinity')::numeric, 0),
          coalesce((v_action.payload->>'gene_cooperation')::numeric, 0.5),
          p_tick_no,
          jsonb_build_object('admin_spawned', true)
        )
        returning id into v_entity_id;

        insert into alife.event_log (
          world_id,
          tick_no,
          event_type,
          severity,
          target_entity_id,
          x,
          y,
          title,
          description,
          payload
        )
        values (
          p_world_id,
          p_tick_no,
          'admin_spawn',
          'notice',
          v_entity_id,
          (v_action.payload->>'x')::integer,
          (v_action.payload->>'y')::integer,
          'An admin shaped new life',
          'A new entity was spawned by admin action.',
          v_action.payload
        );

      elsif v_action.action_type = 'bless_entity' then
        v_entity_id := (v_action.payload->>'entity_id')::bigint;

        update alife.entities
        set
          energy = energy + coalesce((v_action.payload->>'energy')::numeric, 20),
          health = health + coalesce((v_action.payload->>'health')::numeric, 10),
          updated_at = now()
        where world_id = p_world_id
          and id = v_entity_id
          and alive;

        if not found then
          raise exception 'Entity % not found or not alive', v_entity_id;
        end if;

        insert into alife.event_log (
          world_id,
          tick_no,
          event_type,
          severity,
          entity_id,
          title,
          description,
          payload
        )
        values (
          p_world_id,
          p_tick_no,
          'admin_blessing',
          'notice',
          v_entity_id,
          'A life was blessed',
          'Admin action increased health and energy.',
          v_action.payload
        );

      elsif v_action.action_type = 'storm' then
        update alife.entities
        set
          energy = greatest(0, energy - coalesce((v_action.payload->>'energy_damage')::numeric, 8)),
          health = greatest(0, health - coalesce((v_action.payload->>'health_damage')::numeric, 4)),
          updated_at = now()
        where world_id = p_world_id
          and alive
          and abs(x - (v_action.payload->>'x')::integer) <= coalesce((v_action.payload->>'radius')::integer, 3)
          and abs(y - (v_action.payload->>'y')::integer) <= coalesce((v_action.payload->>'radius')::integer, 3);

        insert into alife.event_log (
          world_id,
          tick_no,
          event_type,
          severity,
          x,
          y,
          title,
          description,
          payload
        )
        values (
          p_world_id,
          p_tick_no,
          'admin_storm',
          'warning',
          (v_action.payload->>'x')::integer,
          (v_action.payload->>'y')::integer,
          'A storm crossed the world',
          'Admin action damaged entities in a local region.',
          v_action.payload
        );

      elsif v_action.action_type = 'observe' then
        insert into alife.event_log (
          world_id,
          tick_no,
          event_type,
          severity,
          x,
          y,
          title,
          description,
          payload
        )
        values (
          p_world_id,
          p_tick_no,
          'admin_observation',
          'info',
          nullif(v_action.payload->>'x', '')::integer,
          nullif(v_action.payload->>'y', '')::integer,
          'The world was observed',
          coalesce(v_action.payload->>'note', 'Admin observation recorded.'),
          v_action.payload
        );

      else
        raise exception 'Unsupported admin action type %', v_action.action_type;
      end if;

      update alife.admin_actions
      set
        status = 'applied',
        applied_tick = p_tick_no,
        applied_at = now(),
        result = jsonb_build_object('ok', true)
      where id = v_action.id;

      v_applied := v_applied + 1;

    exception when others then
      update alife.admin_actions
      set
        status = 'rejected',
        applied_tick = p_tick_no,
        applied_at = now(),
        result = jsonb_build_object('ok', false, 'error', sqlerrm)
      where id = v_action.id;
    end;
  end loop;

  return v_applied;
end;
$$;

create or replace function alife.execute_world_tick(p_world_id bigint)
returns bigint
language plpgsql
as $$
declare
  v_next_tick bigint;
  v_tick_no bigint;
begin
  select tick_no + 1
  into v_next_tick
  from alife.worlds
  where id = p_world_id;

  if v_next_tick is null then
    raise exception 'World % not found', p_world_id;
  end if;

  perform alife.apply_admin_actions(p_world_id, v_next_tick);
  v_tick_no := alife.execute_tick(p_world_id);

  return v_tick_no;
end;
$$;
