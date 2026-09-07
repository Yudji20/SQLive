import { getWorldSnapshotData } from "@/lib/world-data";
import { createAdminAction } from "@/app/actions";
import { RealtimeBridge } from "@/app/realtime-bridge";

const terrainClass: Record<string, string> = {
  forest: "tileForest",
  plains: "tilePlains",
  mountain: "tileMountain",
  water: "tileWater",
  ruins: "tileRuins",
  swamp: "tileSwamp",
  desert: "tileDesert",
};

export default async function Home() {
  const world = await getWorldSnapshotData();

  return (
    <main className="shell">
      <RealtimeBridge worldSlug="eldergrove" />
      <section className="topbar" aria-label="World status">
        <div>
          <p className="eyebrow">SQLive cloud prototype</p>
          <h1>{world.name}</h1>
        </div>
        <div className="tickPanel">
          <span>Tick</span>
          <strong>{world.tickNo}</strong>
        </div>
      </section>

      <section className="dashboard">
        <div className="mapArea">
          <div className="sectionHeader">
            <div>
              <p className="eyebrow">World map</p>
              <h2>Mapa vivo</h2>
            </div>
            <form className="compactActions">
              <button type="button" title="Run one tick">1x</button>
              <button type="button" title="Run ten ticks">10x</button>
              <button type="button" title="Pause simulation">II</button>
            </form>
          </div>

          <div
            className="worldGrid"
            style={{
              gridTemplateColumns: `repeat(${world.width}, minmax(0, 1fr))`,
            }}
            aria-label="Fantasy world grid"
          >
            {world.tiles.map((tile) => {
              const hasEntity = world.entities.some(
                (entity) => entity.x === tile.x && entity.y === tile.y,
              );
              return (
                <div
                  className={`tile ${terrainClass[tile.terrain] ?? "tilePlains"}`}
                  key={`${tile.x}-${tile.y}`}
                  title={`${tile.x},${tile.y} ${tile.terrain}`}
                >
                  {hasEntity ? <span /> : null}
                </div>
              );
            })}
          </div>
        </div>

        <aside className="sidePanel">
          <section>
            <p className="eyebrow">Metrics</p>
            <div className="metricGrid">
              {world.metrics.map((metric) => (
                <div className="metric" key={metric.label}>
                  <span>{metric.label}</span>
                  <strong>{metric.value}</strong>
                </div>
              ))}
            </div>
          </section>

          <section>
            <p className="eyebrow">Entities</p>
            <div className="entityList">
              {world.entities.map((entity) => (
                <article className="entity" key={entity.id}>
                  <div>
                    <strong>{entity.name}</strong>
                    <span>{entity.species}</span>
                  </div>
                  <div className="entityStats">
                    <span>G{entity.generation}</span>
                    <span>{entity.energy} EN</span>
                  </div>
                </article>
              ))}
            </div>
          </section>

          <section>
            <p className="eyebrow">Admin actions</p>
            <form className="adminPanel" action={createAdminAction}>
              <div className="fieldRow">
                <label>
                  X
                  <input name="x" type="number" defaultValue={10} min={1} />
                </label>
                <label>
                  Y
                  <input name="y" type="number" defaultValue={10} min={1} />
                </label>
              </div>
              <label>
                Species
                <select name="species_key" defaultValue="mossling">
                  <option value="mossling">Mossling</option>
                  <option value="ash_wolf">Ash Wolf</option>
                  <option value="glimmer_sprite">Glimmer Sprite</option>
                </select>
              </label>
              <label>
                Entity ID
                <input name="entity_id" type="number" defaultValue={101} min={1} />
              </label>
              <label>
                Radius
                <input name="radius" type="number" defaultValue={3} min={1} max={12} />
              </label>
              <div className="adminGrid">
                <button name="action_type" value="spawn_entity" type="submit">
                  Spawn
                </button>
                <button name="action_type" value="bless_entity" type="submit">
                  Bless
                </button>
                <button name="action_type" value="storm" type="submit">
                  Storm
                </button>
                <button name="action_type" value="observe" type="submit">
                  Observe
                </button>
              </div>
            </form>
          </section>
        </aside>
      </section>

      <section className="eventBand">
        <div className="sectionHeader">
          <div>
            <p className="eyebrow">Event log</p>
            <h2>Ultimos acontecimentos</h2>
          </div>
        </div>
        <div className="eventList">
          {world.events.map((event) => (
            <article className="event" key={event.id}>
              <span>{event.tick}</span>
              <strong>{event.title}</strong>
              <p>{event.description}</p>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
