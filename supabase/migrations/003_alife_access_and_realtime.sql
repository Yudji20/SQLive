alter table alife.worlds
  add column if not exists visibility text not null default 'private';

alter table alife.worlds
  drop constraint if exists worlds_visibility_check;

alter table alife.worlds
  add constraint worlds_visibility_check check (visibility in ('private', 'public'));

create table if not exists alife.world_members (
  world_id bigint not null references alife.worlds(id) on delete cascade,
  user_id uuid not null,
  role text not null default 'viewer',
  created_at timestamptz not null default now(),
  primary key (world_id, user_id),
  constraint world_members_role_check check (role in ('viewer', 'admin', 'owner'))
);

create index if not exists world_members_user_id_idx
  on alife.world_members (user_id);

alter table alife.world_members enable row level security;

grant usage on schema alife to anon, authenticated;

grant select on
  alife.worlds,
  alife.tiles,
  alife.species,
  alife.factions,
  alife.entities,
  alife.resources,
  alife.event_log,
  alife.world_metrics,
  alife.v_world_overview
to anon, authenticated;

grant select on alife.world_members to authenticated;

grant select, insert on alife.admin_actions to authenticated;

grant usage, select on all sequences in schema alife to authenticated;

create policy worlds_public_select
on alife.worlds
for select
to anon, authenticated
using (visibility = 'public');

create policy worlds_member_select
on alife.worlds
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = worlds.id
      and wm.user_id = (select auth.uid())
  )
);

create policy world_members_self_select
on alife.world_members
for select
to authenticated
using (user_id = (select auth.uid()));

create policy tiles_public_select
on alife.tiles
for select
to anon, authenticated
using (
  exists (
    select 1
    from alife.worlds w
    where w.id = tiles.world_id
      and w.visibility = 'public'
  )
);

create policy tiles_member_select
on alife.tiles
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = tiles.world_id
      and wm.user_id = (select auth.uid())
  )
);

create policy species_public_select
on alife.species
for select
to anon, authenticated
using (
  exists (
    select 1
    from alife.worlds w
    where w.id = species.world_id
      and w.visibility = 'public'
  )
);

create policy species_member_select
on alife.species
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = species.world_id
      and wm.user_id = (select auth.uid())
  )
);

create policy factions_public_select
on alife.factions
for select
to anon, authenticated
using (
  exists (
    select 1
    from alife.worlds w
    where w.id = factions.world_id
      and w.visibility = 'public'
  )
);

create policy factions_member_select
on alife.factions
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = factions.world_id
      and wm.user_id = (select auth.uid())
  )
);

create policy entities_public_select
on alife.entities
for select
to anon, authenticated
using (
  exists (
    select 1
    from alife.worlds w
    where w.id = entities.world_id
      and w.visibility = 'public'
  )
);

create policy entities_member_select
on alife.entities
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = entities.world_id
      and wm.user_id = (select auth.uid())
  )
);

create policy resources_public_select
on alife.resources
for select
to anon, authenticated
using (
  exists (
    select 1
    from alife.worlds w
    where w.id = resources.world_id
      and w.visibility = 'public'
  )
);

create policy resources_member_select
on alife.resources
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = resources.world_id
      and wm.user_id = (select auth.uid())
  )
);

create policy event_log_public_select
on alife.event_log
for select
to anon, authenticated
using (
  exists (
    select 1
    from alife.worlds w
    where w.id = event_log.world_id
      and w.visibility = 'public'
  )
);

create policy event_log_member_select
on alife.event_log
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = event_log.world_id
      and wm.user_id = (select auth.uid())
  )
);

create policy world_metrics_public_select
on alife.world_metrics
for select
to anon, authenticated
using (
  exists (
    select 1
    from alife.worlds w
    where w.id = world_metrics.world_id
      and w.visibility = 'public'
  )
);

create policy world_metrics_member_select
on alife.world_metrics
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = world_metrics.world_id
      and wm.user_id = (select auth.uid())
  )
);

create policy admin_actions_member_insert
on alife.admin_actions
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and status = 'pending'
  and exists (
    select 1
    from alife.world_members wm
    where wm.world_id = admin_actions.world_id
      and wm.user_id = (select auth.uid())
      and wm.role in ('admin', 'owner')
  )
);

create policy admin_actions_member_select
on alife.admin_actions
for select
to authenticated
using (
  exists (
    select 1
    from alife.world_members wm
    where wm.world_id = admin_actions.world_id
      and wm.user_id = (select auth.uid())
      and wm.role in ('admin', 'owner')
  )
);

do $$
begin
  if not exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'alife'
      and tablename = 'event_log'
  ) then
    alter publication supabase_realtime add table alife.event_log;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'alife'
      and tablename = 'world_metrics'
  ) then
    alter publication supabase_realtime add table alife.world_metrics;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'alife'
      and tablename = 'worlds'
  ) then
    alter publication supabase_realtime add table alife.worlds;
  end if;
end;
$$;
