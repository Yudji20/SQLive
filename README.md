# SQLife

Um pequeno laboratorio de Artificial Life em SQL Server.

> Evolucao do projeto: a versao cloud/fantasia esta sendo planejada em
> [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), com roadmap em
> [docs/ROADMAP.md](docs/ROADMAP.md).

O experimento simula organismos em uma grade 2D. Cada organismo tem energia,
idade, posicao e genes evolutivos:

- `gene_speed`: quantos passos tenta andar por tick.
- `gene_metabolism`: energia consumida por tick.
- `gene_reproduction`: energia minima para gerar um filho.
- `gene_strength`: vantagem em disputas por alimento.
- `gene_mass`: aumenta forca efetiva, mas reduz mobilidade e custa energia.

A cada tick, o mundo executa:

1. envelhecimento e custo metabolico;
2. movimento orientado para comida percebida, ou aleatorio sem alvo;
3. disputa e consumo de recursos na mesma posicao;
4. reproducao com idade minima e pequena mutacao;
5. morte por energia zerada ou idade maxima;
6. reposicao de alimento;
7. registro de metricas.

O fitness nao e uma coluna calculada. Ele emerge de quem consegue sobreviver e
se reproduzir.

## Como Rodar

Execute os scripts em ordem no SQL Server:

```sql
:r sql/00_run_all.sql
```

No `sqlcmd`, rode a partir da raiz do projeto:

```powershell
sqlcmd -S .\SQLEXPRESS -E -d SuaBase -i sql\00_run_all.sql
```

Troque `.\SQLEXPRESS` e `SuaBase` pela instancia e base que voce usa.

Se o seu cliente SQL nao suporta `:r`, abra estes arquivos e execute
manualmente, nesta ordem:

```sql
sql/01_schema.sql
sql/02_procedures.sql
sql/03_demo.sql
```

## Consultas Uteis

Metricas por tick:

```sql
SELECT *
FROM life.v_metrics_recent
ORDER BY tick_no;
```

Organismos vivos:

```sql
SELECT *
FROM life.v_alive_organisms
ORDER BY energy DESC;
```

Genes por geracao:

```sql
SELECT
    generation,
    COUNT(*) AS organisms,
    AVG(gene_speed) AS avg_speed,
    AVG(gene_metabolism) AS avg_metabolism,
    AVG(gene_reproduction) AS avg_reproduction
FROM life.organism_history
GROUP BY generation
ORDER BY generation;
```

Linhagem de um organismo:

```sql
DECLARE @organism_id bigint =
(
    SELECT TOP (1) organism_id
    FROM life.organism
    WHERE alive = 1
    ORDER BY generation DESC, energy DESC
);

EXEC life.show_lineage @organism_id;
```

## Cloud: Supabase + Vercel

A versao cloud roda o site em Next.js na pasta `web/` e usa Supabase/Postgres
como motor publico da simulacao. O SQL Server continua sendo o laboratorio
local, mas as regras principais tambem foram portadas para
`supabase/migrations/005_sqlife_selection_engine.sql`.

No Supabase, aplique as migrations em ordem:

```text
supabase/migrations/001_alife_foundation.sql
supabase/migrations/002_alife_engine_mvp.sql
supabase/migrations/003_alife_access_and_realtime.sql
supabase/migrations/004_alife_admin_actions.sql
supabase/migrations/005_sqlife_selection_engine.sql
```

Depois de aplicar as migrations, crie/reset o mundo cloud pelo endpoint do
site:

```powershell
Invoke-RestMethod -Method Post `
  -Uri "https://SEU-SITE.vercel.app/api/simulation" `
  -ContentType "application/json" `
  -Body '{
    "slug": "eldergrove",
    "name": "SQLife - cloud experimento",
    "width": 60,
    "height": 60,
    "initial_organisms": 80,
    "initial_resources": 350,
    "food_energy": 10.0,
    "food_sense_radius": 6,
    "mutation_rate": 0.08,
    "mutation_strength": 0.12,
    "min_reproduction_age": 20,
    "max_age": 220,
    "visibility": "public"
  }'
```

Para rodar ticks manualmente:

```powershell
Invoke-RestMethod -Method Post `
  -Uri "https://SEU-SITE.vercel.app/api/tick" `
  -ContentType "application/json" `
  -Body '{"ticks": 50}'
```

No Vercel, importe o repositorio GitHub e configure:

- Root Directory: `web`
- Build Command: `npm run build`
- Output Directory: `.next`
- Environment Variables: `NEXT_PUBLIC_SUPABASE_URL`,
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
  `NEXT_PUBLIC_SITE_URL`, `SQLIVE_WORLD_SLUG`
