# Gini e entropia no SQL Server

Funcoes para calcular a **impureza de Gini** e a **entropia de Shannon em bits**,
usando as mesmas formulas das consultas com `GROUP BY class`:

- `dbo.fn_gini`: `1 - SUM(p * p)`.
- `dbo.fn_entropia`: `-SUM(p * LOG(p) / LOG(2.0))`.

Cada funcao recebe `dbo.FrequenciasClasse`, uma tabela com a coluna `Qtd`
(`bigint`). Passe **uma linha por classe**, obtida com `COUNT_BIG(*)` e
`GROUP BY`. Os rotulos das classes nao precisam ser enviados.

## Instalar e executar o exemplo

Requer SQL Server 2016 SP1 ou posterior. Na raiz do repositorio:

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -d SuaBase -b -i sql\statistics\run_all.sql
```

Troque a instancia e `SuaBase` pela sua base de destino. O script cria o tipo,
cria/atualiza as duas funcoes e executa os testes. Pode ser executado novamente.
Os dados ficticios ficam na tabela temporaria `#DadosFicticios`, criada pelo
exemplo e removida ao terminar. O exemplo usa apenas os registros inseridos
nesse script.

No SSMS, habilite o modo SQLCMD e execute `run_all.sql` com os caminhos `:r`
apontando para a raiz do repositorio. Sem modo SQLCMD, execute manualmente:

1. `class_frequencies.sql`;
2. `fn_gini.sql`;
3. `fn_entropia.sql`;
4. `example_and_tests.sql`.

O exemplo tem 10 registros: 8 da classe `0` e 2 da classe `1`.

| GINI | ENTROPIA |
| ---: | ---: |
| 0.32 | 0.7219280948873623 |

Os testes tambem verificam classes equilibradas, uma classe pura com frequencia
zero, tres classes, entrada vazia, todas as frequencias zeradas e um total acima
do limite de `bigint`. A comparacao usa tolerancia de `1e-12` e gera `THROW` se
algum resultado divergir.

## Exemplo com tabela temporaria

Depois de instalar as funcoes na base em que esta executando a consulta:

```sql
DROP TABLE IF EXISTS #DadosFicticios;

CREATE TABLE #DadosFicticios
(
    Id int NOT NULL PRIMARY KEY,
    Class int NOT NULL
);

INSERT INTO #DadosFicticios (Id, Class)
VALUES (1, 0), (2, 0), (3, 0), (4, 0), (5, 0),
       (6, 0), (7, 0), (8, 0), (9, 1), (10, 1);

DECLARE @Frequencias dbo.FrequenciasClasse;

INSERT INTO @Frequencias (Qtd)
SELECT COUNT_BIG(*)
FROM #DadosFicticios
GROUP BY Class;

SELECT dbo.fn_gini(@Frequencias) AS GINI,
       dbo.fn_entropia(@Frequencias) AS ENTROPIA;

DROP TABLE #DadosFicticios;
```

## Comportamento

- Retorno `float`; pequenas diferencas de arredondamento sao esperadas.
- Uma classe com todas as observacoes retorna `0` nas duas funcoes.
- Frequencias zero sao ignoradas, evitando `LOG(0)` na entropia.
- Tabela vazia ou total zero retorna `NULL`, como as consultas originais sem linhas.
- Frequencias negativas e `NULL` sao rejeitadas pelo tipo de tabela.
- O total e somado como `float` para evitar overflow de `SUM(bigint)`.
- Uma `class` nula na tabela de origem e tratada como um grupo pelo `GROUP BY`.

Referencias: [CREATE FUNCTION](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql?view=sql-server-ver17)
e [LOG](https://learn.microsoft.com/en-us/sql/t-sql/functions/log-transact-sql?view=sql-server-ver17).
