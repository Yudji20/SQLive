# SQLive Cloud Architecture

SQLive vai sair de uma simulacao local em SQL Server e virar um mundo persistente
em cloud, com observacao em tempo real, interferencia admin e agentes com
cerebros evolutivos.

## Objetivo

Criar um mundo de fantasia que continua existindo mesmo quando o computador local
esta desligado.

O sistema deve permitir:

- ver o mundo por um site;
- executar ticks automaticamente;
- registrar tudo que acontece;
- interferir no mundo por comandos admin;
- futuramente conversar com um agente admin pelo site ou Telegram;
- evoluir cerebros neurais dos agentes por selecao natural.

## Stack Recomendada

```text
Supabase
  Postgres: fonte da verdade do mundo
  Cron: execucao periodica dos ticks
  Realtime: eventos ao vivo para o site
  Auth: usuarios e admins
  Storage: assets, mapas renderizados, exportacoes

Vercel
  Next.js: site e painel do mundo
  API Routes: comandos admin, Telegram webhook, endpoints seguros

Worker Neural
  Comeco: inferencia/neuroevolucao leve no backend
  Futuro: worker Python separado para treino pesado
```

## Principio Arquitetural

O banco guarda a verdade. O site e o bot nao alteram o mundo diretamente.

Em vez disso, eles criam intencoes:

```text
site/bot
  -> admin_action
  -> tick do mundo processa
  -> event_log registra consequencia
  -> site recebe atualizacao
```

Isso evita efeitos invisiveis e cria uma historia auditavel.

## Camadas

### 1. World State

Estado atual do mundo.

Tabelas principais:

- `alife.worlds`
- `alife.tiles`
- `alife.resources`
- `alife.species`
- `alife.factions`
- `alife.entities`

### 2. Simulation Engine

Regras que avancam o mundo.

Futuras funcoes:

- `alife.execute_tick(world_id)`
- `alife.apply_admin_actions(world_id)`
- `alife.build_observations(world_id)`
- `alife.resolve_decisions(world_id)`
- `alife.apply_metabolism(world_id)`
- `alife.resolve_movement(world_id)`
- `alife.resolve_combat(world_id)`
- `alife.resolve_reproduction(world_id)`
- `alife.capture_metrics(world_id)`

### 3. Neural Decision Layer

Cada agente pode ter um cerebro pequeno.

Fluxo:

```text
estado local
  -> observacao
  -> brain weights
  -> outputs
  -> action_queue
  -> tick aplica consequencia
```

No comeco, a rede deve ser pequena:

```text
inputs:
  energia, saude, idade
  comida norte/sul/leste/oeste
  aliado perto, inimigo perto

outputs:
  mover norte/sul/leste/oeste
  descansar
  reproduzir
  atacar
```

### 4. Interface

O site deve ser construido como um painel operacional do mundo:

- mapa 2D;
- entidades vivas;
- metricas globais;
- eventos recentes;
- acoes admin;
- replay por tick;
- chat admin.

### 5. Bot

O Telegram deve chamar a mesma API do site.

Exemplo:

```text
/spawn dragon x=20 y=14
```

vira:

```json
{
  "action_type": "spawn_entity",
  "payload": {
    "species_key": "dragon",
    "x": 20,
    "y": 14
  }
}
```

## Decisao Importante

Para o MVP, o schema `alife` deve ficar privado e ser acessado pelo backend
server-side. A chave `service_role` nunca deve ir para o browser.

Depois podemos expor leituras publicas por views ou RPCs com RLS bem definida.

