# Report 004 - Supabase Readiness Review

## Objetivo

Confirmar se a parte Supabase/Postgres esta adequada para continuarmos o
desenvolvimento do mundo cloud.

## Resultado

Status: adequada para continuar desenvolvimento local e preparar deploy.

Ainda nao esta validada em um projeto Supabase real, porque este ambiente nao
tem Supabase CLI, `psql` ou MCP Supabase autenticado.

## Pontos Adequados

- O schema principal esta isolado em `alife`.
- A modelagem suporta multiplos mundos por `world_id`.
- As FKs compostas evitam referencias entre mundos diferentes.
- Todas as tabelas centrais tem RLS habilitado.
- A view `alife.v_world_overview` usa `security_invoker = true`.
- As tabelas centrais para o futuro neural ja existem:
  - `agent_brains`;
  - `brain_weights`;
  - `decision_log`;
  - `action_queue`.
- Acoes externas foram modeladas como intencoes em `admin_actions`.
- Eventos do mundo ficam auditaveis em `event_log`.
- O motor MVP ja tem funcoes para:
  - criar mundo demo;
  - capturar metricas;
  - executar tick basico.

## Ajuste Feito Nesta Revisao

- Removido o vinculo circular opcional `entities.brain_id`.
- Mantido o relacionamento de cerebro por `agent_brains.entity_id`.

Essa modelagem e mais simples para o MVP: uma entidade pode ter zero ou um
cerebro, e o cerebro aponta para a entidade.

## Pontos Que Ainda Precisam Entrar

- Policies RLS reais para leitura publica/autenticada.
- Grants para schemas/tabelas/funcoes conforme o modo de acesso escolhido.
- Configuracao de Realtime.
- Configuracao de Cron.
- Funcao de processamento de `admin_actions`.
- Funcao de criacao/copia/mutacao de cerebros.
- Teste real das migrations em Supabase/Postgres.

## Decisao Recomendada

Para a proxima fase, manter o schema `alife` privado e acessar pelo backend
server-side usando service role na Vercel.

Depois expor somente o que o frontend precisa por:

- API routes do Next.js;
- views/RPCs especificas;
- Realtime Broadcast ou Postgres Changes com filtros.

## Proxima Etapa

Criar uma migration `003_alife_access_and_realtime.sql` com:

- roles/policies iniciais;
- grants minimos;
- publicacao Realtime para eventos/metricas, se usarmos Postgres Changes;
- ou triggers de Broadcast, se formos pelo caminho mais escalavel.

