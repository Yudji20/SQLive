# Report 008 - Realtime Bridge

## Objetivo

Preparar o frontend para reagir a atualizacoes ao vivo do Supabase.

## Feito

- Criado `web/lib/supabase-browser.ts`.
- Criado componente client `web/app/realtime-bridge.tsx`.
- A home agora monta o Realtime bridge.
- O bridge assina mudancas em:
  - `alife.event_log`;
  - `alife.world_metrics`.
- Ao receber evento, o frontend chama `router.refresh()`.

## Comportamento

- Sem `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, o
  bridge nao faz nada e o site continua funcionando com mock.
- Com variaveis configuradas, o site atualiza quando o mundo gerar eventos ou
  novas metricas.

## Verificacao

- `npm run build` passou apos adicionar o Realtime bridge.

## Pendente

- Validar assinatura Realtime contra Supabase real.
- Confirmar que o schema `alife` esta exposto/permitido para Realtime no projeto.
- Ajustar filtros por `world_id` se houver muitos mundos ativos.

