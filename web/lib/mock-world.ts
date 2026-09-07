type Terrain = "forest" | "plains" | "mountain" | "water" | "ruins" | "swamp";

type Tile = {
  x: number;
  y: number;
  terrain: Terrain;
};

type Entity = {
  id: number;
  name: string;
  species: string;
  generation: number;
  energy: number;
  health: number;
  age: number;
  speed: number;
  metabolism: number;
  reproduction: number;
  strength: number;
  mass: number;
  x: number;
  y: number;
  genes: {
    speed: number;
    metabolism: number;
    reproduction: number;
    strength: number;
    mass: number;
  };
};

type Event = {
  id: number;
  tick: number;
  title: string;
  description: string;
};

export async function getWorldSnapshot() {
  const width = 32;
  const height = 20;
  const tiles: Tile[] = [];

  for (let y = 1; y <= height; y += 1) {
    for (let x = 1; x <= width; x += 1) {
      const value = (x * 17 + y * 31 + ((x - y) * (x + y))) % 23;
      const terrain: Terrain =
        value < 3
          ? "water"
          : value < 6
            ? "mountain"
            : value < 11
              ? "forest"
              : value === 13
                ? "ruins"
                : value === 17
                  ? "swamp"
                  : "plains";

      tiles.push({ x, y, terrain });
    }
  }

  const entities: Entity[] = [
    { id: 101, name: "Mossling 101", species: "Mossling", generation: 8, energy: 31, health: 100, age: 42, speed: 2.9, metabolism: 0.71, reproduction: 34, strength: 2.2, mass: 1.8, x: 8, y: 6, genes: { speed: 2.9, metabolism: 0.71, reproduction: 34, strength: 2.2, mass: 1.8 } },
    { id: 144, name: "Ash Wolf 144", species: "Ash Wolf", generation: 5, energy: 42, health: 100, age: 68, speed: 2.1, metabolism: 0.84, reproduction: 38, strength: 3.4, mass: 2.6, x: 19, y: 9, genes: { speed: 2.1, metabolism: 0.84, reproduction: 38, strength: 3.4, mass: 2.6 } },
    { id: 177, name: "Glimmer Sprite 177", species: "Glimmer Sprite", generation: 11, energy: 28, health: 100, age: 25, speed: 3.8, metabolism: 0.63, reproduction: 31, strength: 1.5, mass: 1.1, x: 24, y: 13, genes: { speed: 3.8, metabolism: 0.63, reproduction: 31, strength: 1.5, mass: 1.1 } },
    { id: 203, name: "Mossling 203", species: "Mossling", generation: 12, energy: 35, health: 100, age: 21, speed: 3.1, metabolism: 0.69, reproduction: 32, strength: 2.8, mass: 2.0, x: 12, y: 15, genes: { speed: 3.1, metabolism: 0.69, reproduction: 32, strength: 2.8, mass: 2.0 } },
    { id: 231, name: "Ash Wolf 231", species: "Ash Wolf", generation: 6, energy: 39, health: 100, age: 81, speed: 1.9, metabolism: 0.91, reproduction: 41, strength: 4.0, mass: 3.1, x: 27, y: 5, genes: { speed: 1.9, metabolism: 0.91, reproduction: 41, strength: 4.0, mass: 3.1 } },
  ];

  const events: Event[] = [
    {
      id: 1,
      tick: 304,
      title: "A new life emerged",
      description: "A Mossling lineage reproduced near the western forest.",
    },
    {
      id: 2,
      tick: 302,
      title: "Resource bloom",
      description: "Mana bloomed around the old ruins and attracted sprites.",
    },
    {
      id: 3,
      tick: 299,
      title: "A life ended",
      description: "An elder creature exhausted its energy crossing the ridge.",
    },
  ];

  return {
    name: "Eldergrove",
    tickNo: 304,
    width,
    height,
    tiles,
    entities,
    resources: [
      { id: 1, x: 9, y: 6, kind: "food", energy: 10 },
      { id: 2, x: 18, y: 9, kind: "food", energy: 10 },
      { id: 3, x: 12, y: 15, kind: "food", energy: 10 },
    ],
    events,
    metrics: [
      { label: "Population", value: "317" },
      { label: "Avg energy", value: "13.9" },
      { label: "Avg age", value: "47.4" },
      { label: "Max gen", value: "16" },
      { label: "Resources", value: "350" },
      { label: "Avg speed", value: "3.55" },
      { label: "Avg metabolism", value: "0.60" },
      { label: "Avg reproduction", value: "34.1" },
      { label: "Avg strength", value: "2.74" },
      { label: "Avg mass", value: "2.12" },
    ],
    raw: {
      metrics: [],
      resourcesCount: 3,
      organismsCount: entities.length,
    },
  };
}
