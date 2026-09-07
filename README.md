# SQLife

Um pequeno laboratorio de Artificial Life em SQL Server.

> Evolucao do projeto: a versao cloud/fantasia esta sendo planejada em
> [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), com roadmap em
> [docs/ROADMAP.md](docs/ROADMAP.md).

O experimento simula organismos em uma grade 2D. Cada organismo tem energia,
idade, posicao e tres genes:

- `gene_speed`: quantos passos tenta andar por tick.
- `gene_metabolism`: energia consumida por tick.
- `gene_reproduction`: energia minima para gerar um filho.

A cada tick, o mundo executa:

1. envelhecimento e custo metabolico;
2. movimento aleatorio;
3. consumo de recursos na mesma posicao;
4. reproducao com pequena mutacao;
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
