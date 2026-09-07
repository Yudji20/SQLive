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

function organismSpeed(organism: Organism) {
  return organism.genes?.speed ?? organism.speed ?? 0;
}

function organismMetabolism(organism: Organism) {
  return organism.genes?.metabolism ?? organism.metabolism ?? 0;
}

function organismStrength(organism: Organism) {
  return organism.genes?.strength ?? organism.strength ?? 0;
}

function organismMass(organism: Organism) {
  return organism.genes?.mass ?? organism.mass ?? 0;
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

function average(values: number[]) {
  if (values.length === 0) {
    return 0;
  }

  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function formatMetricNumber(value: number, digits = 2) {
  return Number.isFinite(value) ? value.toFixed(digits) : "-";
}

function correlation(items: Organism[], readA: (organism: Organism) => number, readB: (organism: Organism) => number) {
  if (items.length < 2) {
    return 0;
  }

  const valuesA = items.map(readA);
  const valuesB = items.map(readB);
  const avgA = average(valuesA);
  const avgB = average(valuesB);
  const numerator = items.reduce(
    (sum, _, index) => sum + (valuesA[index] - avgA) * (valuesB[index] - avgB),
    0,
  );
  const denominatorA = Math.sqrt(valuesA.reduce((sum, value) => sum + (value - avgA) ** 2, 0));
  const denominatorB = Math.sqrt(valuesB.reduce((sum, value) => sum + (value - avgB) ** 2, 0));

  if (denominatorA === 0 || denominatorB === 0) {
    return 0;
  }

  return numerator / (denominatorA * denominatorB);
}

function quadrantLabel(organism: Organism, width: number, height: number) {
  const vertical = organism.y <= height / 2 ? "Norte" : "Sul";
  const horizontal = organism.x <= width / 2 ? "Oeste" : "Leste";

  return `${vertical}-${horizontal}`;
}

function buildSpatialBands(world: WorldSnapshot | null) {
  if (!world) {
    return [];
  }

  const labels = ["Norte-Oeste", "Norte-Leste", "Sul-Oeste", "Sul-Leste"];

  return labels.map((label) => {
    const organisms = world.entities.filter(
      (organism) => quadrantLabel(organism, world.width, world.height) === label,
    );

    return {
      label,
      count: organisms.length,
      share: world.entities.length ? (organisms.length / world.entities.length) * 100 : 0,
      avgSpeed: average(organisms.map(organismSpeed)),
      avgMetabolism: average(organisms.map(organismMetabolism)),
      avgStrength: average(organisms.map(organismStrength)),
      avgMass: average(organisms.map(organismMass)),
      avgEnergy: average(organisms.map((organism) => organism.energy)),
    };
  });
}

function dominantQuadrant(organisms: Organism[], width: number, height: number) {
  if (organisms.length === 0) {
    return "-";
  }

  const counts = new Map<string, number>();

  organisms.forEach((organism) => {
    const label = quadrantLabel(organism, width, height);
    counts.set(label, (counts.get(label) ?? 0) + 1);
  });

  return [...counts.entries()].sort((left, right) => right[1] - left[1])[0]?.[0] ?? "-";
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

    return buildFallbackTiles(world.width, world.height);
  }, [world]);

  const resourcePoints = useMemo(
    () => new Set((world?.resources ?? []).map(pointKey)),
    [world?.resources],
  );
  const organismPoints = useMemo(() => new Set((world?.entities ?? []).map(pointKey)), [world?.entities]);
  const fastestOrganisms = useMemo(() => {
    const organisms = [...(world?.entities ?? [])].sort((left, right) => organismSpeed(right) - organismSpeed(left));
    const take = Math.max(1, Math.ceil(organisms.length * 0.25));

    return organisms.slice(0, take);
  }, [world?.entities]);
  const fastestPoints = useMemo(() => new Set(fastestOrganisms.map(pointKey)), [fastestOrganisms]);
  const strongestOrganisms = useMemo(() => {
    const organisms = [...(world?.entities ?? [])].sort(
      (left, right) => organismStrength(right) - organismStrength(left),
    );
    const take = Math.max(1, Math.ceil(organisms.length * 0.25));

    return organisms.slice(0, take);
  }, [world?.entities]);
  const strongestPoints = useMemo(() => new Set(strongestOrganisms.map(pointKey)), [strongestOrganisms]);
  const spatialBands = useMemo(() => buildSpatialBands(world), [world]);
  const fastAvgX = average(fastestOrganisms.map((organism) => organism.x));
  const fastAvgY = average(fastestOrganisms.map((organism) => organism.y));
  const strongAvgX = average(strongestOrganisms.map((organism) => organism.x));
  const strongAvgY = average(strongestOrganisms.map((organism) => organism.y));
  const speedXCorrelation = correlation(world?.entities ?? [], organismSpeed, (organism) => organism.x);
  const speedYCorrelation = correlation(world?.entities ?? [], organismSpeed, (organism) => organism.y);
  const strengthXCorrelation = correlation(world?.entities ?? [], organismStrength, (organism) => organism.x);
  const strengthYCorrelation = correlation(world?.entities ?? [], organismStrength, (organism) => organism.y);
  const fastestQuadrant =
    fastestOrganisms.length > 0 && world
      ? dominantQuadrant(fastestOrganisms, world.width, world.height)
      : "-";
  const strongestQuadrant =
    strongestOrganisms.length > 0 && world
      ? dominantQuadrant(strongestOrganisms, world.width, world.height)
      : "-";
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
              const hasFastOrganism = fastestPoints.has(key);
              const hasStrongOrganism = strongestPoints.has(key);

              return (
                <span
                  className={[
                    "tile",
                    hasOrganism ? "organism" : "",
                    hasResource ? "resource" : "",
                    hasOrganism && hasResource ? "both" : "",
                    hasFastOrganism ? "fastOrganism" : "",
                    hasStrongOrganism ? "strongOrganism" : "",
                    hasFastOrganism && hasStrongOrganism ? "fastStrongOrganism" : "",
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
            <span><i className="fastSample" /> top 25% velocidade</span>
            <span><i className="strongSample" /> top 25% forca</span>
            <span><i className="fastStrongSample" /> velocidade + forca</span>
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

      <section className="analysisPanel">
        <div className="sectionTitle">
          <div>
            <h2>Leitura emergente</h2>
            <p>Primeira camada para observar agrupamento espacial dos genes.</p>
          </div>
          <span>top 25% por velocidade e forca</span>
        </div>

        <div className="insightGrid">
          <article>
            <span>Centro dos mais rapidos</span>
            <strong>x {formatMetricNumber(fastAvgX, 1)} · y {formatMetricNumber(fastAvgY, 1)}</strong>
          </article>
          <article>
            <span>Quadrante dominante</span>
            <strong>{fastestQuadrant}</strong>
          </article>
          <article>
            <span>Correlacao velocidade x X</span>
            <strong>{formatMetricNumber(speedXCorrelation, 3)}</strong>
          </article>
          <article>
            <span>Correlacao velocidade x Y</span>
            <strong>{formatMetricNumber(speedYCorrelation, 3)}</strong>
          </article>
          <article>
            <span>Centro dos mais fortes</span>
            <strong>x {formatMetricNumber(strongAvgX, 1)} · y {formatMetricNumber(strongAvgY, 1)}</strong>
          </article>
          <article>
            <span>Quadrante forca</span>
            <strong>{strongestQuadrant}</strong>
          </article>
          <article>
            <span>Correlacao forca x X</span>
            <strong>{formatMetricNumber(strengthXCorrelation, 3)}</strong>
          </article>
          <article>
            <span>Correlacao forca x Y</span>
            <strong>{formatMetricNumber(strengthYCorrelation, 3)}</strong>
          </article>
        </div>

        <div className="tableWrap compactTable">
          <table>
            <thead>
              <tr>
                <th>Regiao</th>
                <th>Pop</th>
                <th>Distribuicao</th>
                <th>Vel</th>
                <th>Met</th>
                <th>For</th>
                <th>Massa</th>
                <th>Energia</th>
              </tr>
            </thead>
            <tbody>
              {spatialBands.map((band) => (
                <tr key={band.label}>
                  <td>{band.label}</td>
                  <td>{band.count}</td>
                  <td>
                    <span className="barTrack">
                      <span style={{ width: `${Math.min(100, band.share)}%` }} />
                    </span>
                  </td>
                  <td>{formatMetricNumber(band.avgSpeed)}</td>
                  <td>{formatMetricNumber(band.avgMetabolism)}</td>
                  <td>{formatMetricNumber(band.avgStrength)}</td>
                  <td>{formatMetricNumber(band.avgMass)}</td>
                  <td>{formatMetricNumber(band.avgEnergy, 1)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
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
