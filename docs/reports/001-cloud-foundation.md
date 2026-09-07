# Report 001 - Cloud Foundation

## Objetivo

Preparar o projeto para sair do SQL Server local e ir para uma arquitetura cloud
com Supabase e Vercel.

## Feito

- Definida arquitetura alvo: Supabase como fonte da verdade, Vercel como site/API.
- Definida separacao entre estado do mundo, motor de tick, interface e bot.
- Criado roadmap incremental.
- Criada primeira migration Postgres/Supabase v2.
- Adicionado `.gitignore` para evitar commit de credenciais e arquivos locais.
- Atualizado `README.md` apontando para a arquitetura cloud.

## Decisoes

- O schema principal sera `alife`.
- O mundo sera manipulado por eventos e filas de acao, nao por updates diretos do site.
- O site e o bot devem criar `admin_actions`.
- O tick processa essas acoes e escreve em `event_log`.
- A rede neural sera inicialmente neuroevolutiva, com pesos herdados e mutados.
- O schema `alife` nasce com RLS habilitado em todas as tabelas.
- A primeira fase deve ser acessada pelo backend server-side, nao diretamente pelo browser.
- Entidades, especies, faccoes e cerebros foram amarrados por `world_id` para evitar referencias entre mundos diferentes.

## Verificacao

- Arquivos criados listados com `rg --files`.
- Checagem de caracteres nao ASCII concluida sem ocorrencias.
- Revisao estatica da migration confirmou tabelas, indices, FKs compostas e RLS.

## Pendente

- Nao foi possivel executar a migration porque este ambiente ainda nao tem `psql`
  nem Supabase CLI instalado/configurado.
- A validacao real deve acontecer quando houver um projeto Supabase conectado ou
  uma instancia Postgres local.

## Proxima Etapa

Criar as funcoes Postgres iniciais:

- criar mundo demo;
- gerar mapa;
- semear especies/faccoes/entidades;
- executar tick basico.
