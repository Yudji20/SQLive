# Report 007 - Web Build And Admin Actions

## Objetivo

Conferir a instalacao do frontend, validar build e continuar com a etapa de
admin actions.

## Feito

- Confirmado que `node_modules` e `package-lock.json` existem em `web/`.
- Corrigido `tsconfig.json` para TypeScript 7 removendo `baseUrl`.
- `npm run build` passou com sucesso.
- Criada migration `004_alife_admin_actions.sql`.
- Criada funcao `alife.apply_admin_actions(world_id, tick_no)`.
- Criada funcao wrapper `alife.execute_world_tick(world_id)`.
- Atualizados smoke tests e docs para usar `execute_world_tick`.
- Atualizada Edge Function `tick-world` para chamar `execute_world_tick`.
- Criado endpoint `POST /api/admin-actions`.
- Criado Server Action `createAdminAction`.
- Painel admin da home agora tem controles para:
  - spawn;
  - bless;
  - storm;
  - observe.

## Verificacao

- Build Next.js passou.
- `GET /api/world` respondeu `200`.
- `POST /api/tick` respondeu `200`.
- `POST /api/admin-actions` respondeu `200` em modo mock.
- Primeira verificacao visual mostrou a pagina renderizando mapa, metricas,
  entidades, eventos e acoes admin sem overlay nem erros de console.

## Limitacao

- Depois de recarregar a aba, o navegador controlado ficou em uma pagina de
  connection refused, embora o servidor local continuasse respondendo via HTTP.
  Por isso, a validacao final ficou baseada em build + HTTP + primeira captura
  visual.

## Pendente

- Criar `.env` local ou expor ferramenta Supabase MCP para validar com dados
  reais.
- Aplicar migrations `001` a `004` no Supabase.
- Rodar `supabase/sql/smoke_test.sql`.
- Ligar Realtime no frontend.

