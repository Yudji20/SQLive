# SQLive API local

API HTTP simples para ligar o SQL Server local a uma visualizacao HTML minima do
SQLive.

## Configuracao

Defina as variaveis de ambiente antes de iniciar:

```powershell
$env:SQLIVE_SQLSERVER = "localhost\SQLEXPRESS"
$env:SQLIVE_DATABASE = "SQLive"
$env:SQLIVE_USER = "app"
$env:SQLIVE_PASSWORD = "sua_senha"
python teste_api\api.py
```

Se preferir autenticacao integrada do Windows, deixe `SQLIVE_USER` e
`SQLIVE_PASSWORD` vazios.

Depois abra:

```text
http://127.0.0.1:8000/
```

## Rotas

- `GET /`: abre o painel HTML local.
- `GET /status`: testa a conexao com o SQL Server.
- `GET /world`: retorna o snapshot completo para o front.
- `GET /metrics?limit=50`: retorna metricas recentes.
- `GET /organisms?limit=200`: retorna organismos vivos.
- `GET /resources?limit=1000`: retorna recursos atuais.
- `POST /simulation`: cria uma simulacao com os parametros do mundo.
- `POST /tick`: executa ticks na simulacao.

Exemplo:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/world
Invoke-RestMethod http://127.0.0.1:8000/tick -Method Post -ContentType "application/json" -Body '{"ticks": 1}'
Invoke-RestMethod http://127.0.0.1:8000/simulation -Method Post -ContentType "application/json" -Body '{"name":"SQLife - API","width":60,"height":60,"initial_organisms":80,"initial_resources":350,"food_energy":10.0,"food_sense_radius":6,"mutation_rate":0.08,"mutation_strength":0.12,"min_reproduction_age":20,"max_age":220}'
```

Quando `simulation_id` nao for informado, a API usa a simulacao mais recente.
