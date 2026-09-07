"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

type Metric = {
  label: string;
  value: string;
};

type Tile = {
  x: number;
  y: number;
  terrain?: string;
};

type Organism = {
  id: number;
  name: string;
  species?: string;
  generation: number;
  energy: number;
  health?: number;
  age?: number;
  x: number;
  y: number;
  speed?: number;
  metabolism?: number;
  reproduction?: number;
  strength?: number;
  mass?: number;
  genes?: {
    speed?: number;
    metabolism?: number;
    reproduction?: number;
    strength?: number;
    mass?: number;
  };
};

type Resource = {
  id: number;
  x: number;
  y: number;
  kind?: string;
  energy?: number;
};

type EventItem = {
  id: number | string;
  tick: number;
  title: string;
  description: string;
};

type MetricPoint = {
  tick_no: number;
  population: number;
  alive_entities: number;
  resource_total: number;
  avg_energy: number | null;
  avg_age?: number | null;
  avg_generation: number | null;
  avg_gene_speed: number | null;
  avg_gene_metabolism: number | null;
  avg_gene_reproduction?: number | null;
  avg_gene_strength?: number | null;
  avg_gene_mass?: number | null;
};

type WorldSnapshot = {
  mode?: string;
  simulationId?: number;
  slug?: string;
  name: string;
  tickNo: number;
  width: number;
  height: number;
  tiles: Tile[];
  entities: Organism[];
  resources?: Resource[];
  events: EventItem[];
  metrics: Metric[];
  raw?: {
    metrics?: MetricPoint[];
    resourcesCount?: number;
    organismsCount?: number;
  };
};

const intervalOptions = [1, 5, 10, 15, 30];

function metricValue(world: WorldSnapshot | null, label: string) {
  return world?.metrics.find((metric) => metric.label === label)?.value ?? "-";
}

function pointKey(point: { x: number; y: number }) {
  return `${point.x}:${point.y}`;
}

function formatGene(value: number | undefined) {
  return typeof value === "number" ? value.toFixed(2) : "-";
}

function buildFallbackTiles(width: number, height: number) {
  return Array.from({ length: width * height }, (_, index) => ({
    x: (index % width) + 1,
    y: Math.floor(index / width) + 1,
  }));
}

export function SqliveDashboard() {
  const [world, setWorld] = useState<WorldSnapshot | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [autoTick, setAutoTick] = useState(false);
  const [intervalSeconds, setIntervalSeconds] = useState(15);
  const [countdown, setCountdown] = useState(15);

  const loadWorld = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await fetch("/api/world", { cache: "no-store" });
      const data = (await response.json()) as WorldSnapshot & { ok?: boolean; error?: string };

      if (!response.ok || data.ok === false) {
        throw new Error(data.error ?? "Falha ao carregar o mundo.");
      }

      setWorld(data);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Falha ao carregar o mundo.");
    } finally {
      setLoading(false);
    }
  }, []);

  const runTicks = useCallback(
    async (ticks: number) => {
      setLoading(true);
      setError(null);

      try {
        const response = await fetch("/api/tick", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ ticks }),
        });
        const data = (await response.json()) as { ok?: boolean; error?: string };

        if (!response.ok || data.ok === false) {
          throw new Error(data.error ?? "Falha ao executar tick.");
        }

        await loadWorld();
      } catch (caught) {
        setError(caught instanceof Error ? caught.message : "Falha ao executar tick.");
      } finally {
        setLoading(false);
      }
    },
    [loadWorld],
  );

  useEffect(() => {
    loadWorld();
  }, [loadWorld]);

  useEffect(() => {
    if (!autoTick) {
      setCountdown(intervalSeconds);
      return undefined;
    }

    const timer = window.setInterval(() => {
      setCountdown((current) => {
        if (current <= 1) {
          void runTicks(1);
          return intervalSeconds;
        }

        return current - 1;
      });
    }, 1000);

    return () => window.clearInterval(timer);
  }, [autoTick, intervalSeconds, runTicks]);

  const tiles = useMemo(() => {
    if (!world) {
      return [];
    }

    return world.tiles.length ? world.tiles : buildFallbackTiles(world.width, world.height);
  }, [world]);

  const resourcePoints = useMemo(
    () => new Set((world?.resources ?? []).map(pointKey)),
    [world?.resources],
  );
  const organismPoints = useMemo(() => new Set((world?.entities ?? []).map(pointKey)), [world?.entities]);
  const metricHistory = world?.raw?.metrics ?? [];

  return (
    <main className="app">
      <header className="topbar">
        <div>
          <p className="eyebrow">Supabase conectado ao Vercel</p>
          <h1>{world?.name ?? "SQLive"}</h1>
          <p className="subtle">
            {world?.slug ? `mundo ${world.slug}` : "carregando mundo"} ·{" "}
            {world?.mode ?? "aguardando"} · {world?.width ?? "-"} x {world?.height ?? "-"}
          </p>
        </div>
        <div className="status">
          <span>{loading ? "sincronizando" : error ? "erro" : "online"}</span>
          <strong>Tick {world?.tickNo ?? "-"}</strong>
        </div>
      </header>

      <section className="toolbar" aria-label="Controles da simulacao">
        <button type="button" onClick={loadWorld} disabled={loading}>
          Atualizar
        </button>
        <button type="button" onClick={() => runTicks(1)} disabled={loading}>
          Rodar 1 tick
        </button>
        <button type="button" onClick={() => runTicks(10)} disabled={loading}>
          Rodar 10 ticks
        </button>
        <button type="button" onClick={() => runTicks(50)} disabled={loading}>
          Rodar 50 ticks
        </button>
        <label className="checkControl">
          <input
            checked={autoTick}
            onChange={(event) => setAutoTick(event.currentTarget.checked)}
            type="checkbox"
          />
          auto tick
        </label>
        <span className="countdown">
          {autoTick ? `proximo tick em ${countdown}s` : `auto tick parado (${intervalSeconds}s)`}
        </span>
      </section>

      <section className="intervalSelector" aria-label="Intervalo do auto tick">
        <span>Intervalo:</span>
        <div className="intervalOptions">
          {intervalOptions.map((seconds) => (
            <button
              aria-pressed={intervalSeconds === seconds}
              className={intervalSeconds === seconds ? "isSelected" : ""}
              key={seconds}
              onClick={() => {
                setIntervalSeconds(seconds);
                setCountdown(seconds);
              }}
              type="button"
            >
              {seconds}s
            </button>
          ))}
        </div>
      </section>

      <section className="summary" aria-label="Metricas principais">
        <article>
          <span>Populacao</span>
          <strong>{metricValue(world, "Population")}</strong>
        </article>
        <article>
          <span>Recursos</span>
          <strong>{metricValue(world, "Resources")}</strong>
        </article>
        <article>
          <span>Energia media</span>
          <strong>{metricValue(world, "Avg energy")}</strong>
        </article>
        <article>
          <span>Idade media</span>
          <strong>{metricValue(world, "Avg age")}</strong>
        </article>
        <article>
          <span>Velocidade</span>
          <strong>{metricValue(world, "Avg speed")}</strong>
        </article>
        <article>
          <span>Metabolismo</span>
          <strong>{metricValue(world, "Avg metabolism")}</strong>
        </article>
        <article>
          <span>Forca</span>
          <strong>{metricValue(world, "Avg strength")}</strong>
        </article>
        <article>
          <span>Massa</span>
          <strong>{metricValue(world, "Avg mass")}</strong>
        </article>
      </section>

      <section className="workspace">
        <section className="mapPanel" aria-label="Mapa do mundo">
          <div className="sectionTitle">
            <div>
              <h2>Mapa</h2>
              <p>{world?.entities.length ?? 0} organismos exibidos · {world?.resources?.length ?? 0} recursos ativos</p>
            </div>
            <span>{world ? `${world.width} x ${world.height}` : "-"}</span>
          </div>
          <div
            className="worldGrid"
            style={{ gridTemplateColumns: `repeat(${world?.width ?? 1}, minmax(0, 1fr))` }}
          >
            {tiles.map((tile) => {
              const key = pointKey(tile);
              const hasOrganism = organismPoints.has(key);
              const hasResource = resourcePoints.has(key);

              return (
                <span
                  className={[
                    "tile",
                    hasOrganism ? "organism" : "",
                    hasResource ? "resource" : "",
                    hasOrganism && hasResource ? "both" : "",
                  ]
                    .filter(Boolean)
                    .join(" ")}
                  key={key}
                  title={`${tile.x}, ${tile.y}`}
                />
              );
            })}
          </div>
          <div className="legend">
            <span><i className="organismSample" /> organismo</span>
            <span><i className="resourceSample" /> recurso</span>
            <span><i className="bothSample" /> disputa/comida</span>
          </div>
        </section>

        <aside className="sidePanel">
          <section>
            <div className="sectionTitle">
              <h2>Organismos vivos</h2>
              <span>{world?.entities.length ?? 0}</span>
            </div>
            <div className="organismList">
              {(world?.entities ?? []).slice(0, 40).map((organism) => (
                <article className="organismRow" key={organism.id}>
                  <div className="rowTop">
                    <strong>#{organism.id}</strong>
                    <span>G{organism.generation}</span>
                  </div>
                  <p>
                    x:{organism.x} y:{organism.y} · energia:{organism.energy} · idade:{organism.age ?? "-"}
                  </p>
                  <div className="geneLine">
                    <span>vel {formatGene(organism.genes?.speed ?? organism.speed)}</span>
                    <span>met {formatGene(organism.genes?.metabolism ?? organism.metabolism)}</span>
                    <span>rep {formatGene(organism.genes?.reproduction ?? organism.reproduction)}</span>
                    <span>for {formatGene(organism.genes?.strength ?? organism.strength)}</span>
                    <span>mas {formatGene(organism.genes?.mass ?? organism.mass)}</span>
                  </div>
                </article>
              ))}
            </div>
          </section>

          <section>
            <div className="sectionTitle">
              <h2>Eventos recentes</h2>
            </div>
            <div className="eventList">
              {(world?.events ?? []).slice(0, 10).map((event) => (
                <article className="eventRow" key={event.id}>
                  <div className="rowTop">
                    <strong>{event.title}</strong>
                    <span>{event.tick}</span>
                  </div>
                  <p>{event.description}</p>
                </article>
              ))}
            </div>
          </section>
        </aside>
      </section>

      <section className="dataPanel">
        <div className="sectionTitle">
          <h2>Historico recente</h2>
          <span>{metricHistory.length} pontos</span>
        </div>
        <div className="tableWrap">
          <table>
            <thead>
              <tr>
                <th>Tick</th>
                <th>Pop</th>
                <th>Recursos</th>
                <th>Energia</th>
                <th>Geracao</th>
                <th>Vel</th>
                <th>Met</th>
                <th>For</th>
                <th>Massa</th>
              </tr>
            </thead>
            <tbody>
              {metricHistory.slice(0, 20).map((metric) => (
                <tr key={metric.tick_no}>
                  <td>{metric.tick_no}</td>
                  <td>{metric.alive_entities ?? metric.population}</td>
                  <td>{Number(metric.resource_total).toFixed(0)}</td>
                  <td>{metric.avg_energy?.toFixed(1) ?? "-"}</td>
                  <td>{metric.avg_generation?.toFixed(1) ?? "-"}</td>
                  <td>{metric.avg_gene_speed?.toFixed(2) ?? "-"}</td>
                  <td>{metric.avg_gene_metabolism?.toFixed(2) ?? "-"}</td>
                  <td>{metric.avg_gene_strength?.toFixed(2) ?? "-"}</td>
                  <td>{metric.avg_gene_mass?.toFixed(2) ?? "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {error ? <p className="errorBox">{error}</p> : null}
    </main>
  );
}
