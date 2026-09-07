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
  speed: number;
  strength: number;
  mass: number;
  x: number;
  y: number;
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
    { id: 101, name: "Mossling 101", species: "Mossling", generation: 8, energy: 31, speed: 2.9, strength: 2.2, mass: 1.8, x: 8, y: 6 },
    { id: 144, name: "Ash Wolf 144", species: "Ash Wolf", generation: 5, energy: 42, speed: 2.1, strength: 3.4, mass: 2.6, x: 19, y: 9 },
    { id: 177, name: "Glimmer Sprite 177", species: "Glimmer Sprite", generation: 11, energy: 28, speed: 3.8, strength: 1.5, mass: 1.1, x: 24, y: 13 },
    { id: 203, name: "Mossling 203", species: "Mossling", generation: 12, energy: 35, speed: 3.1, strength: 2.8, mass: 2.0, x: 12, y: 15 },
    { id: 231, name: "Ash Wolf 231", species: "Ash Wolf", generation: 6, energy: 39, speed: 1.9, strength: 4.0, mass: 3.1, x: 27, y: 5 },
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
    events,
    metrics: [
      { label: "Population", value: "317" },
      { label: "Avg energy", value: "13.9" },
      { label: "Max gen", value: "16" },
      { label: "Resources", value: "350" },
      { label: "Avg speed", value: "3.55" },
      { label: "Avg metabolism", value: "0.60" },
      { label: "Avg strength", value: "2.74" },
      { label: "Avg mass", value: "2.12" },
    ],
  };
}
