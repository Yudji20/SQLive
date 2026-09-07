# Report 002 - Postgres Engine MVP

## Objetivo

Comecar o motor de simulacao em Postgres/Supabase, ainda sem site e sem
Telegram.

## Feito

- Criada migration `002_alife_engine_mvp.sql`.
- Criada funcao `alife.capture_metrics(world_id)`.
- Criada funcao `alife.create_demo_world(...)`.
- Criada funcao `alife.execute_tick(world_id)`.
- Adicionados genes fisicos explicitos em `alife.entities`.
- Adicionadas medias dos genes em `alife.world_metrics`.

## O Que O Motor Ja Faz

- Cria um mundo fantasia demo chamado `Eldergrove`.
- Gera tiles com terrenos e biomas.
- Semeia especies iniciais:
  - Mossling;
  - Ash Wolf;
  - Glimmer Sprite.
- Semeia faccoes:
  - The Wild;
  - Grove Court.
- Semeia recursos de comida e mana.
- Avanca ticks.
- Aplica metabolismo.
- Move entidades.
- Permite consumo de recursos.
- Permite reproducao com mutacao dos genes fisicos.
- Registra nascimentos e mortes em `event_log`.
- Captura metricas globais por tick.

## Decisoes

- O MVP ainda usa movimento aleatorio.
- A rede neural ja tem tabelas de suporte, mas ainda nao decide acoes.
- Entidades nao devem ser deletadas normalmente; morte e `alive = false`.
- Eventos preservam a historia do mundo.

## Verificacao

- Revisao estatica feita nos arquivos SQL.
- Checado que nao ha caracteres nao ASCII.
- Corrigido insert de especies em lote.
- Corrigida divisao de energia para nao afetar filhos nascidos no mesmo tick.

## Pendente

- Executar as migrations em Postgres/Supabase real.
- Ajustar qualquer detalhe de sintaxe que so apareca em execucao real.
- Criar seed/teste de smoke:
  - `select alife.create_demo_world();`
  - `select alife.execute_tick(1);`
  - `select * from alife.v_world_overview;`

