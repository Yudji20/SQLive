# Supabase Setup

Este arquivo e o checklist para aplicar o SQLive em um projeto Supabase real.

## 1. Aplicar Migrations

No Supabase SQL Editor, execute nesta ordem:

```text
supabase/migrations/001_alife_foundation.sql
supabase/migrations/002_alife_engine_mvp.sql
supabase/migrations/003_alife_access_and_realtime.sql
```

## 2. Criar Mundo Demo

Execute:

```sql
select alife.create_demo_world(
  p_slug => 'eldergrove',
  p_name => 'Eldergrove',
  p_width => 40,
  p_height => 30,
  p_initial_entities => 80
) as world_id;
```

Para deixar o mundo visivel pelo cliente anonimo:

```sql
update alife.worlds
set visibility = 'public'
where slug = 'eldergrove';
```

## 3. Smoke Test

Execute:

```sql
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
```

Ou execute o arquivo:

```text
supabase/sql/smoke_test.sql
```

## 4. Data API

O site usa `@supabase/supabase-js` pelo backend. Para acessar o schema `alife`
via Supabase Data API, confirme no Dashboard:

```text
Project Settings -> API -> Exposed schemas
```

Inclua `alife` se quiser que o backend use o client Supabase diretamente.

## 5. Realtime

A migration 003 adiciona estas tabelas na publicacao `supabase_realtime`:

```text
alife.event_log
alife.world_metrics
alife.worlds
```

Para MVP, isso e suficiente para painel ao vivo.

## 6. Edge Function

Deploy da funcao:

```text
supabase/functions/tick-world/index.ts
```

Variaveis necessarias:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
SQLIVE_CRON_SECRET
```

## 7. Cron

Use o template:

```text
supabase/sql/cron_setup_template.sql
```

Troque:

```text
PROJECT_URL
CRON_SECRET
```

Depois execute no SQL Editor.

## 8. Vercel

Configure no projeto Vercel:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY
SQLIVE_WORLD_SLUG=eldergrove
SQLIVE_CRON_SECRET
```

Nunca coloque `SUPABASE_SERVICE_ROLE_KEY` em variaveis `NEXT_PUBLIC_`.
