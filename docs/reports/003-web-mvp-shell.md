# Report 003 - Web MVP Shell

## Objetivo

Criar a primeira casca do site que vai permitir observar e controlar o mundo.

## Feito

- Criado app Next.js em `web/`.
- Criada tela inicial com:
  - mapa 2D;
  - metricas;
  - entidades;
  - acoes admin;
  - log de eventos.
- Criado mock de snapshot do mundo em `web/lib/mock-world.ts`.
- Criado endpoint `GET /api/world`.
- Criado endpoint `POST /api/tick`.
- Criado helper server-side `createSupabaseAdminClient`.
- Criado `.env.example` para variaveis Supabase.
- Fixadas versoes de dependencias no `package.json`.

## Decisoes

- O site comeca com dados mockados para permitir evoluir UI sem depender ainda do Supabase real.
- O runtime fica no padrao Node.js do Next.js.
- Leituras internas podem usar Server Components.
- Webhooks e integracoes externas devem usar Route Handlers.
- `SUPABASE_SERVICE_ROLE_KEY` deve existir apenas no servidor/Vercel, nunca no browser.

## Verificacao

- Estrutura de arquivos revisada.
- Checagem de caracteres nao ASCII concluida sem ocorrencias.
- Dependencias foram fixadas em versoes especificas:
  - Next.js `16.3.4`;
  - React `19.2.8`;
  - Supabase JS `2.115.0`.

## Pendente

- `npm install` ficou sem saida por tempo demais neste ambiente e foi interrompido.
- Ainda nao foi possivel rodar `npm run build` nem subir `npm run dev`.
- Quando o npm conseguir acessar o registry, rodar:

```powershell
cd web
npm install
npm run build
npm run dev
```

