import json
import mimetypes
import os
from datetime import date, datetime
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import pyodbc


BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"


def load_env_file(path):
    if not path.is_file():
        return

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()

        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue

        name, value = stripped.split("=", 1)
        name = name.strip()
        value = value.strip().strip('"').strip("'")

        if name and name not in os.environ:
            os.environ[name] = value


load_env_file(BASE_DIR / ".env")


HOST = os.getenv("SQLIVE_API_HOST", "127.0.0.1")
PORT = int(os.getenv("SQLIVE_API_PORT", "8000"))
MAX_TICKS_PER_REQUEST = 50


class ApiError(Exception):
    def __init__(self, status_code, message):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


def _env(name, default=None):
    value = os.getenv(name, default)
    if value is None or value == "":
        return None
    return value


def build_connection_string():
    raw_connection_string = _env("SQLIVE_SQLSERVER_CONNECTION_STRING")
    if raw_connection_string:
        return raw_connection_string

    server = _env("SQLIVE_SQLSERVER")
    database = _env("SQLIVE_DATABASE")
    user = _env("SQLIVE_USER")
    password = _env("SQLIVE_PASSWORD")
    driver = _env("SQLIVE_DRIVER") or choose_default_driver()
    encrypt = _env("SQLIVE_ENCRYPT", "no")
    trust_server_certificate = _env("SQLIVE_TRUST_SERVER_CERTIFICATE", "yes")

    if not server or not database:
        raise ApiError(
            500,
            "Configure SQLIVE_SQLSERVER e SQLIVE_DATABASE antes de acessar o banco.",
        )

    parts = [
        f"DRIVER={{{driver}}}",
        f"SERVER={server}",
        f"DATABASE={database}",
    ]

    if driver != "SQL Server":
        parts.extend(
            [
                f"Encrypt={encrypt}",
                f"TrustServerCertificate={trust_server_certificate}",
            ]
        )

    if user and password:
        parts.extend([f"UID={user}", f"PWD={password}"])
    else:
        parts.append("Trusted_Connection=yes")

    return ";".join(parts)


def choose_default_driver():
    preferred_drivers = [
        "SQL Server",
        "ODBC Driver 17 for SQL Server",
        "ODBC Driver 18 for SQL Server",
    ]
    installed_drivers = set(pyodbc.drivers())

    for driver in preferred_drivers:
        if driver in installed_drivers:
            return driver

    raise ApiError(
        500,
        "Nenhum driver ODBC do SQL Server foi encontrado. Instale o ODBC Driver 17 ou 18.",
    )


def get_connection():
    return pyodbc.connect(build_connection_string(), autocommit=True)


def json_default(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def rows_to_dicts(cursor):
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def get_int_param(query, name, default=None):
    raw_value = query.get(name, [None])[0]
    if raw_value in (None, ""):
        return default

    try:
        return int(raw_value)
    except ValueError as exc:
        raise ApiError(400, f"Parametro '{name}' precisa ser um numero inteiro.") from exc


def get_body_int(body, name, default):
    raw_value = body.get(name, default)
    if raw_value in (None, ""):
        return default

    try:
        return int(raw_value)
    except (TypeError, ValueError) as exc:
        raise ApiError(400, f"Campo '{name}' precisa ser um numero inteiro.") from exc


def get_body_float(body, name, default):
    raw_value = body.get(name, default)
    if raw_value in (None, ""):
        return default

    try:
        return float(raw_value)
    except (TypeError, ValueError) as exc:
        raise ApiError(400, f"Campo '{name}' precisa ser um numero.") from exc


def get_body_text(body, name, default):
    raw_value = body.get(name, default)
    if raw_value in (None, ""):
        return default

    return str(raw_value)


def get_latest_simulation_id(cursor):
    row = cursor.execute(
        """
        SELECT TOP (1) simulation_id
        FROM life.simulation
        ORDER BY simulation_id DESC
        """
    ).fetchone()

    if not row:
        raise ApiError(
            404,
            "Nenhuma simulacao encontrada. Execute os scripts SQL antes de chamar a API.",
        )

    return int(row.simulation_id)


def resolve_simulation_id(cursor, query):
    simulation_id = get_int_param(query, "simulation_id")
    if simulation_id is not None:
        return simulation_id
    return get_latest_simulation_id(cursor)


def get_simulation(cursor, simulation_id):
    row = cursor.execute(
        """
        SELECT
            simulation_id,
            name,
            width,
            height,
            tick_no,
            food_target,
            food_energy,
            food_sense_radius,
            mutation_rate,
            mutation_strength,
            min_reproduction_age,
            max_age,
            created_at
        FROM life.simulation
        WHERE simulation_id = ?
        """,
        simulation_id,
    ).fetchone()

    if not row:
        raise ApiError(404, f"Simulacao {simulation_id} nao encontrada.")

    columns = [column[0] for column in cursor.description]
    return dict(zip(columns, row))


def get_alive_organisms(cursor, simulation_id, limit=200):
    cursor.execute(
        """
        SELECT TOP (?)
            organism_id,
            parent_organism_id,
            generation,
            x,
            y,
            energy,
            age,
            gene_speed,
            gene_metabolism,
            gene_reproduction,
            gene_strength,
            gene_mass,
            born_tick
        FROM life.v_alive_organisms
        WHERE simulation_id = ?
        ORDER BY generation DESC, energy DESC, organism_id
        """,
        limit,
        simulation_id,
    )
    return rows_to_dicts(cursor)


def get_resources(cursor, simulation_id, limit=1000):
    cursor.execute(
        """
        SELECT TOP (?)
            resource_id,
            x,
            y,
            energy,
            created_tick
        FROM life.resource
        WHERE simulation_id = ?
        ORDER BY resource_id DESC
        """,
        limit,
        simulation_id,
    )
    return rows_to_dicts(cursor)


def get_recent_metrics(cursor, simulation_id, limit=50):
    cursor.execute(
        """
        SELECT TOP (?)
            tick_no,
            population,
            resources,
            avg_energy,
            avg_age,
            avg_generation,
            avg_gene_speed,
            avg_gene_metabolism,
            avg_gene_reproduction,
            avg_gene_strength,
            avg_gene_mass,
            created_at
        FROM life.metrics
        WHERE simulation_id = ?
        ORDER BY tick_no DESC
        """,
        limit,
        simulation_id,
    )
    return rows_to_dicts(cursor)


def build_tiles(width, height):
    tile_count = width * height
    if tile_count > 10000:
        return []

    return [
        {"x": x, "y": y, "terrain": "plains"}
        for y in range(1, height + 1)
        for x in range(1, width + 1)
    ]


def format_metric(value, digits=1):
    if value is None:
        return "-"
    return f"{float(value):.{digits}f}"


def build_world_snapshot(cursor, simulation_id):
    simulation = get_simulation(cursor, simulation_id)
    organisms = get_alive_organisms(cursor, simulation_id)
    resources = get_resources(cursor, simulation_id)
    metrics = get_recent_metrics(cursor, simulation_id, limit=20)
    latest_metric = metrics[0] if metrics else {}

    return {
        "mode": "sqlserver",
        "simulationId": simulation["simulation_id"],
        "name": simulation["name"],
        "tickNo": simulation["tick_no"],
        "width": simulation["width"],
        "height": simulation["height"],
        "tiles": build_tiles(simulation["width"], simulation["height"]),
        "entities": [
            {
                "id": organism["organism_id"],
                "name": f"Organismo {organism['organism_id']}",
                "species": "SQLife",
                "generation": organism["generation"],
                "energy": round(float(organism["energy"])),
                "age": organism["age"],
                "x": organism["x"],
                "y": organism["y"],
                "genes": {
                    "speed": float(organism["gene_speed"]),
                    "metabolism": float(organism["gene_metabolism"]),
                    "reproduction": float(organism["gene_reproduction"]),
                    "strength": float(organism["gene_strength"]),
                    "mass": float(organism["gene_mass"]),
                },
            }
            for organism in organisms
        ],
        "resources": resources,
        "events": [
            {
                "id": f"tick-{metric['tick_no']}",
                "tick": metric["tick_no"],
                "title": f"Tick {metric['tick_no']}",
                "description": (
                    f"Populacao: {metric['population']} | "
                    f"Recursos: {metric['resources']} | "
                    f"Energia media: {format_metric(metric['avg_energy'])}"
                ),
            }
            for metric in metrics[:10]
        ],
        "metrics": [
            {"label": "Population", "value": str(latest_metric.get("population", "-"))},
            {"label": "Resources", "value": str(latest_metric.get("resources", "-"))},
            {"label": "Avg energy", "value": format_metric(latest_metric.get("avg_energy"))},
            {"label": "Avg age", "value": format_metric(latest_metric.get("avg_age"))},
            {"label": "Avg gen", "value": format_metric(latest_metric.get("avg_generation"))},
            {"label": "Avg speed", "value": format_metric(latest_metric.get("avg_gene_speed"), 2)},
            {
                "label": "Avg metabolism",
                "value": format_metric(latest_metric.get("avg_gene_metabolism"), 2),
            },
            {
                "label": "Avg reproduction",
                "value": format_metric(latest_metric.get("avg_gene_reproduction"), 2),
            },
            {
                "label": "Avg strength",
                "value": format_metric(latest_metric.get("avg_gene_strength"), 2),
            },
            {
                "label": "Avg mass",
                "value": format_metric(latest_metric.get("avg_gene_mass"), 2),
            },
        ],
        "raw": {
            "simulation": simulation,
            "metrics": metrics,
        },
    }


def execute_ticks(cursor, simulation_id, ticks):
    if ticks < 1:
        raise ApiError(400, "O numero de ticks precisa ser maior que zero.")
    if ticks > MAX_TICKS_PER_REQUEST:
        raise ApiError(400, f"Execute no maximo {MAX_TICKS_PER_REQUEST} ticks por chamada.")

    executed_ticks = []
    for _ in range(ticks):
        cursor.execute("EXEC life.execute_tick @simulation_id = ?", simulation_id)
        tick_no = cursor.execute(
            "SELECT tick_no FROM life.simulation WHERE simulation_id = ?",
            simulation_id,
        ).fetchone().tick_no
        executed_ticks.append(int(tick_no))

    return executed_ticks


def create_simulation(cursor, body):
    name = get_body_text(body, "name", "SQLife - experimento API")
    width = get_body_int(body, "width", 60)
    height = get_body_int(body, "height", 60)
    initial_organisms = get_body_int(body, "initial_organisms", 80)
    initial_resources = get_body_int(body, "initial_resources", 350)
    food_energy = get_body_float(body, "food_energy", 10.0)
    food_sense_radius = get_body_int(body, "food_sense_radius", 6)
    mutation_rate = get_body_float(body, "mutation_rate", 0.08)
    mutation_strength = get_body_float(body, "mutation_strength", 0.12)
    min_reproduction_age = get_body_int(body, "min_reproduction_age", 20)
    max_age = get_body_int(body, "max_age", 220)

    row = cursor.execute(
        """
        DECLARE @simulation_id int;

        EXEC life.reset_world
            @name = ?,
            @width = ?,
            @height = ?,
            @initial_organisms = ?,
            @initial_resources = ?,
            @food_energy = ?,
            @food_sense_radius = ?,
            @mutation_rate = ?,
            @mutation_strength = ?,
            @min_reproduction_age = ?,
            @max_age = ?,
            @simulation_id = @simulation_id OUTPUT;

        SELECT @simulation_id AS simulation_id;
        """,
        name,
        width,
        height,
        initial_organisms,
        initial_resources,
        food_energy,
        food_sense_radius,
        mutation_rate,
        mutation_strength,
        min_reproduction_age,
        max_age,
    ).fetchone()

    return int(row.simulation_id)


class ApiHandler(BaseHTTPRequestHandler):
    def _send_static_file(self, relative_path):
        requested_path = (STATIC_DIR / relative_path).resolve()

        if STATIC_DIR.resolve() not in requested_path.parents and requested_path != STATIC_DIR.resolve():
            self._send_json(403, {"ok": False, "error": "Acesso negado."})
            return

        if not requested_path.is_file():
            self._send_json(404, {"ok": False, "error": "Arquivo nao encontrado."})
            return

        content = requested_path.read_bytes()
        content_type = mimetypes.guess_type(requested_path.name)[0] or "application/octet-stream"

        if requested_path.suffix == ".js":
            content_type = "text/javascript; charset=utf-8"
        elif requested_path.suffix in (".html", ".css"):
            content_type = f"{content_type}; charset=utf-8"

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def _send_json(self, status_code, data):
        response = json.dumps(data, default=json_default, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(response)

    def _send_error(self, error):
        if isinstance(error, ApiError):
            self._send_json(error.status_code, {"ok": False, "error": error.message})
            return

        self._send_json(500, {"ok": False, "error": str(error)})

    def _read_json_body(self):
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            return {}

        try:
            return json.loads(self.rfile.read(content_length))
        except json.JSONDecodeError as exc:
            raise ApiError(400, "Envie um JSON valido.") from exc

    def do_OPTIONS(self):
        self._send_json(204, {})

    def do_GET(self):
        parsed_url = urlparse(self.path)
        query = parse_qs(parsed_url.query)

        try:
            if parsed_url.path == "/":
                self._send_static_file("index.html")
                return

            if parsed_url.path in ("/styles.css", "/app.js"):
                self._send_static_file(parsed_url.path.lstrip("/"))
                return

            with get_connection() as connection:
                cursor = connection.cursor()

                if parsed_url.path == "/status":
                    cursor.execute("SELECT 1 AS ok")
                    self._send_json(200, {"ok": True, "database": "connected"})
                    return

                simulation_id = resolve_simulation_id(cursor, query)

                if parsed_url.path == "/world":
                    self._send_json(200, build_world_snapshot(cursor, simulation_id))
                    return

                if parsed_url.path == "/metrics":
                    limit = get_int_param(query, "limit", 50)
                    self._send_json(
                        200,
                        {
                            "ok": True,
                            "simulationId": simulation_id,
                            "metrics": get_recent_metrics(cursor, simulation_id, limit),
                        },
                    )
                    return

                if parsed_url.path == "/organisms":
                    limit = get_int_param(query, "limit", 200)
                    self._send_json(
                        200,
                        {
                            "ok": True,
                            "simulationId": simulation_id,
                            "organisms": get_alive_organisms(cursor, simulation_id, limit),
                        },
                    )
                    return

                if parsed_url.path == "/resources":
                    limit = get_int_param(query, "limit", 1000)
                    self._send_json(
                        200,
                        {
                            "ok": True,
                            "simulationId": simulation_id,
                            "resources": get_resources(cursor, simulation_id, limit),
                        },
                    )
                    return

            self._send_json(404, {"ok": False, "error": "Rota nao encontrada."})
        except Exception as error:
            self._send_error(error)

    def do_POST(self):
        parsed_url = urlparse(self.path)
        query = parse_qs(parsed_url.query)

        try:
            if parsed_url.path not in ("/tick", "/simulation"):
                self._send_json(404, {"ok": False, "error": "Rota nao encontrada."})
                return

            body = self._read_json_body()

            with get_connection() as connection:
                cursor = connection.cursor()

                if parsed_url.path == "/simulation":
                    simulation_id = create_simulation(cursor, body)
                    self._send_json(
                        201,
                        {
                            "ok": True,
                            "mode": "sqlserver",
                            "simulationId": simulation_id,
                            "world": build_world_snapshot(cursor, simulation_id),
                        },
                    )
                    return

                simulation_id = body.get("simulation_id") or resolve_simulation_id(cursor, query)
                ticks = int(body.get("ticks", query.get("ticks", [1])[0]))
                executed_ticks = execute_ticks(cursor, int(simulation_id), ticks)

                self._send_json(
                    200,
                    {
                        "ok": True,
                        "mode": "sqlserver",
                        "simulationId": int(simulation_id),
                        "executedTicks": executed_ticks,
                        "world": build_world_snapshot(cursor, int(simulation_id)),
                    },
                )
        except ValueError:
            self._send_json(400, {"ok": False, "error": "Ticks precisa ser um numero inteiro."})
        except Exception as error:
            self._send_error(error)

    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {format % args}")


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), ApiHandler)
    print(f"API rodando em http://{HOST}:{PORT}")
    print("Configure SQLIVE_SQLSERVER, SQLIVE_DATABASE, SQLIVE_USER e SQLIVE_PASSWORD.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nAPI encerrada")
    finally:
        server.server_close()
