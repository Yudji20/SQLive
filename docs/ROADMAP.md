# SQLive Roadmap

## Etapa 1 - Fundacao Cloud

- Criar arquitetura Supabase/Vercel.
- Criar migration Postgres v2.
- Modelar mundo, tiles, especies, faccoes, entidades, eventos e acoes admin.
- Preparar tabelas para cerebro neural.

Status: concluida localmente.

## Etapa 2 - Motor Postgres

- Criar seed de mundo fantasia.
- Criar funcoes pequenas de tick.
- Portar regras do SQL Server para Postgres.
- Registrar eventos narrativos.
- Registrar metricas por tick.

Status: MVP criado localmente; falta validar em Postgres/Supabase real.

## Etapa 3 - Site MVP

- Criar app Next.js.
- Conectar Supabase server-side.
- Mostrar mapa 2D.
- Mostrar eventos e metricas.
- Botao para executar ticks manualmente.

Status: casca visual e endpoints mockados criados; falta instalar dependencias e validar build.

## Etapa 4 - Interferencia Admin

- Criar painel de acoes admin.
- Processar `admin_actions` no tick.
- Criar auditoria e historico de interferencias.

Status: painel, API e processador SQL MVP criados; falta validar em Supabase real.

## Etapa 5 - Neuroevolucao

- Criar observacoes dos agentes.
- Calcular decisoes com rede pequena.
- Copiar/mutar pesos na reproducao.
- Comparar agentes aleatorios contra agentes neurais.

## Etapa 6 - Automacao Cloud

- Agendar ticks com Supabase Cron.
- Atualizar site com Realtime.
- Criar pagina de replay historico.

Status: Edge Function, template de Cron e Realtime bridge preparados; falta deploy/config real no Supabase.

## Etapa 7 - Telegram/Admin Agent

- Criar webhook Telegram.
- Converter comandos em `admin_actions`.
- Adicionar chat admin no site.
- Futuramente usar LLM para interpretar comandos naturais.
