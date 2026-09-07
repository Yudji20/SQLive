const DEFAULT_AUTO_TICK_INTERVAL_SECONDS = 15;
const AUTO_TICK_OPTIONS = [1, 5, 10, 15, 30];

const state = {
  loading: false,
  timer: null,
  tickTimer: null,
  autoTickEnabled: false,
  autoTickSecondsLeft: DEFAULT_AUTO_TICK_INTERVAL_SECONDS,
  autoTickIntervalSeconds: DEFAULT_AUTO_TICK_INTERVAL_SECONDS,
};

const elements = {
  worldName: document.querySelector("#worldName"),
  connectionState: document.querySelector("#connectionState"),
  tickNo: document.querySelector("#tickNo"),
  population: document.querySelector("#population"),
  resourceCount: document.querySelector("#resourceCount"),
  avgEnergy: document.querySelector("#avgEnergy"),
  avgGeneration: document.querySelector("#avgGeneration"),
  worldSize: document.querySelector("#worldSize"),
  worldGrid: document.querySelector("#worldGrid"),
  entityCount: document.querySelector("#entityCount"),
  organismList: document.querySelector("#organismList"),
  eventList: document.querySelector("#eventList"),
  errorBox: document.querySelector("#errorBox"),
  refreshButton: document.querySelector("#refreshButton"),
  tickOneButton: document.querySelector("#tickOneButton"),
  tickTenButton: document.querySelector("#tickTenButton"),
  tickAutoButton: document.querySelector("#tickAutoButton"),
  autoRefresh: document.querySelector("#autoRefresh"),
  autoTickCountdown: document.querySelector("#autoTickCountdown"),
  intervalButtons: Array.from(document.querySelectorAll(".intervalButton")),
};

function metricValue(world, label) {
  const metric = world.metrics?.find((item) => item.label === label);
  return metric?.value ?? "-";
}

function setLoading(isLoading) {
  state.loading = isLoading;
  elements.refreshButton.disabled = isLoading;
  elements.tickOneButton.disabled = isLoading;
  elements.tickTenButton.disabled = isLoading;
  elements.tickAutoButton.disabled = isLoading;
}

function updateAutoTickCountdown() {
  if (!state.autoTickEnabled) {
    elements.autoTickCountdown.textContent = `Atualização automática desativada (intervalo ${state.autoTickIntervalSeconds}s)`;
    return;
  }

  elements.autoTickCountdown.textContent = `Próxima atualização em ${state.autoTickSecondsLeft}s`;
}

function setAutoTickButtonState(isRunning) {
  elements.tickAutoButton.textContent = isRunning ? "Parar atualização automática" : "Atualizar mundo sozinho";
  elements.autoRefresh.checked = isRunning;
  updateAutoTickCountdown();
}

function applyIntervalSelection(seconds) {
  state.autoTickIntervalSeconds = seconds;
  elements.intervalButtons.forEach((button) => {
    const selected = Number(button.dataset.seconds) === seconds;
    button.classList.toggle("is-selected", selected);
    button.setAttribute("aria-pressed", String(selected));
  });

  if (!state.autoTickEnabled) {
    state.autoTickSecondsLeft = seconds;
    updateAutoTickCountdown();
    return;
  }

  state.autoTickSecondsLeft = seconds;
  updateAutoTickCountdown();
}

function stopAutoTick() {
  if (state.tickTimer) {
    clearInterval(state.tickTimer);
    state.tickTimer = null;
  }

  state.autoTickEnabled = false;
  state.autoTickSecondsLeft = state.autoTickIntervalSeconds;
  setAutoTickButtonState(false);
}

function startAutoTick() {
  state.autoTickEnabled = true;
  state.autoTickSecondsLeft = state.autoTickIntervalSeconds;
  setAutoTickButtonState(true);

  if (state.tickTimer) {
    clearInterval(state.tickTimer);
  }

  runTicks(1);
  state.tickTimer = setInterval(() => {
    if (!state.autoTickEnabled) {
      return;
    }

    state.autoTickSecondsLeft -= 1;

    if (state.autoTickSecondsLeft <= 0) {
      state.autoTickSecondsLeft = state.autoTickIntervalSeconds;
      runTicks(1);
    }

    updateAutoTickCountdown();
  }, 1000);
}

function showError(message) {
  elements.errorBox.hidden = !message;
  elements.errorBox.textContent = message ?? "";
}

function pointKey(item) {
  return `${item.x}:${item.y}`;
}

function renderMap(world) {
  const organismPoints = new Set((world.entities ?? []).map(pointKey));
  const resourcePoints = new Set((world.resources ?? []).map(pointKey));
  const width = Number(world.width);
  const height = Number(world.height);
  const tiles = world.tiles?.length ? world.tiles : [];

  elements.worldGrid.style.gridTemplateColumns = `repeat(${width}, minmax(0, 1fr))`;
  elements.worldGrid.innerHTML = "";

  const fragment = document.createDocumentFragment();
  const sourceTiles =
    tiles.length > 0
      ? tiles
      : Array.from({ length: width * height }, (_, index) => ({
          x: (index % width) + 1,
          y: Math.floor(index / width) + 1,
        }));

  for (const tile of sourceTiles) {
    const key = pointKey(tile);
    const hasOrganism = organismPoints.has(key);
    const hasResource = resourcePoints.has(key);
    const cell = document.createElement("span");

    cell.className = "tile";
    if (hasOrganism && hasResource) {
      cell.classList.add("both");
    } else if (hasOrganism) {
      cell.classList.add("organism");
    } else if (hasResource) {
      cell.classList.add("resource");
    }

    cell.title = `${tile.x}, ${tile.y}`;
    fragment.appendChild(cell);
  }

  elements.worldGrid.appendChild(fragment);
}

function renderOrganisms(entities) {
  elements.organismList.innerHTML = "";

  for (const entity of entities.slice(0, 30)) {
    const row = document.createElement("article");
    row.className = "row";
    row.innerHTML = `
      <div class="rowTop">
        <strong>${entity.name}</strong>
        <span>G${entity.generation}</span>
      </div>
      <small>x:${entity.x} y:${entity.y} | energia:${entity.energy} | idade:${entity.age} | força:${entity.genes?.strength?.toFixed(2) ?? "-"} | massa:${entity.genes?.mass?.toFixed(2) ?? "-"}</small>
    `;
    elements.organismList.appendChild(row);
  }
}

function renderEvents(events) {
  elements.eventList.innerHTML = "";

  for (const event of events.slice(0, 10)) {
    const row = document.createElement("article");
    row.className = "row";
    row.innerHTML = `
      <div class="rowTop">
        <strong>${event.title}</strong>
        <span>${event.tick}</span>
      </div>
      <small>${event.description}</small>
    `;
    elements.eventList.appendChild(row);
  }
}

function renderWorld(world) {
  elements.worldName.textContent = world.name ?? "SQLive";
  elements.connectionState.textContent = world.mode === "sqlserver" ? "SQL Server conectado" : "online";
  elements.tickNo.textContent = world.tickNo ?? "-";
  elements.population.textContent = metricValue(world, "Population");
  elements.resourceCount.textContent = metricValue(world, "Resources");
  elements.avgEnergy.textContent = metricValue(world, "Avg energy");
  elements.avgGeneration.textContent = metricValue(world, "Avg gen");
  elements.worldSize.textContent = `${world.width} x ${world.height}`;
  elements.entityCount.textContent = `${world.entities?.length ?? 0} exibidos`;

  renderMap(world);
  renderOrganisms(world.entities ?? []);
  renderEvents(world.events ?? []);
}

async function loadWorld() {
  if (state.loading) {
    return;
  }

  setLoading(true);
  showError(null);

  try {
    const response = await fetch("/world", { cache: "no-store" });
    const data = await response.json();

    if (!response.ok || data.ok === false) {
      throw new Error(data.error ?? "Falha ao carregar mundo.");
    }

    renderWorld(data);
  } catch (error) {
    elements.connectionState.textContent = "erro";
    showError(error.message);
  } finally {
    setLoading(false);
  }
}

async function runTicks(ticks) {
  if (state.loading) {
    return;
  }

  setLoading(true);
  showError(null);

  try {
    const response = await fetch("/tick", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ticks }),
    });
    const data = await response.json();

    if (!response.ok || data.ok === false) {
      throw new Error(data.error ?? "Falha ao executar tick.");
    }

    renderWorld(data.world);
  } catch (error) {
    showError(error.message);
  } finally {
    setLoading(false);
  }
}

elements.refreshButton.addEventListener("click", loadWorld);
elements.tickOneButton.addEventListener("click", () => runTicks(1));
elements.tickTenButton.addEventListener("click", () => runTicks(10));
elements.tickAutoButton.addEventListener("click", () => {
  if (state.autoTickEnabled) {
    stopAutoTick();
    return;
  }

  startAutoTick();
});
elements.autoRefresh.addEventListener("change", () => {
  if (elements.autoRefresh.checked) {
    startAutoTick();
    return;
  }

  stopAutoTick();
});
elements.intervalButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const seconds = Number(button.dataset.seconds);
    applyIntervalSelection(seconds);

    if (state.autoTickEnabled) {
      startAutoTick();
    }
  });
});

applyIntervalSelection(DEFAULT_AUTO_TICK_INTERVAL_SECONDS);
setAutoTickButtonState(false);
loadWorld();
