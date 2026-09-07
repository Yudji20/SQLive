# Report 005 - Access And Realtime Start

## Objetivo

Iniciar a etapa de acesso seguro, Realtime e preparacao para Cron em Supabase.

## Feito

- Criada migration `003_alife_access_and_realtime.sql`.
- Adicionada coluna `visibility` em `alife.worlds`.
- Criada tabela `alife.world_members`.
- Criadas policies RLS iniciais.
- Criados grants minimos para leitura e envio de admin actions.
- Preparada publicacao Realtime para:
  - `alife.event_log`;
  - `alife.world_metrics`;
  - `alife.worlds`.
- Criado smoke test em `supabase/sql/smoke_test.sql`.
- Criado template de Cron em `supabase/sql/cron_setup_template.sql`.

## Decisoes

- Mundos podem ser `private` ou `public`.
- Leitura anonima/autenticada so ve mundos publicos.
- Usuarios autenticados podem criar `admin_actions` apenas se forem admin/owner do mundo.
- O tick automatico deve ser chamado por Edge Function protegida por segredo.

## Pendente

- Aplicar migrations em um projeto Supabase real.
- Executar smoke test.
- Criar Edge Function `tick-world`.
- Substituir valores do template de Cron.
- Confirmar no dashboard se o schema `alife` deve ser exposto pela Data API ou acessado apenas via backend.

