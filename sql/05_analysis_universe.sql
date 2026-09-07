/*==============================================================================
    SQLIFE - EXTRACAO PARA ANALISE DO UNIVERSO

    Ajuste @simulation_id para analisar um experimento especifico.
    Deixe NULL para analisar a simulacao mais recente.
==============================================================================*/

DECLARE @simulation_id INT = NULL;

IF @simulation_id IS NULL
BEGIN
    SELECT
        @simulation_id = MAX(simulation_id)
    FROM life.simulation;
END;

SELECT @simulation_id AS SIMULATION_ID_ANALISADA;


/*==============================================================================
    1. CONFIGURACAO E ESTADO ATUAL DO MUNDO
==============================================================================*/

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
WHERE simulation_id = @simulation_id;


/*==============================================================================
    2. HISTORICO COMPLETO DAS METRICAS

    Principal serie temporal para comparar takeoff, colapso e estabilizacao.
==============================================================================*/

SELECT
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
WHERE simulation_id = @simulation_id
ORDER BY tick_no;


/*==============================================================================
    3. ORGANISMOS VIVOS ATUALMENTE
==============================================================================*/

SELECT
    o.organism_id,
    o.parent_organism_id,
    o.generation,
    o.x,
    o.y,
    o.energy,
    o.age,
    CASE WHEN o.age >= s.min_reproduction_age THEN 1 ELSE 0 END AS is_mature,
    CASE
        WHEN o.age >= s.min_reproduction_age
         AND o.energy >= o.gene_reproduction
            THEN 1
        ELSE 0
    END AS can_reproduce_now,
    o.gene_speed,
    o.gene_metabolism,
    o.gene_reproduction,
    o.gene_strength,
    o.gene_mass,
    o.gene_strength * o.gene_mass AS effective_strength,
    o.gene_speed / (
        1.0
        + CASE WHEN o.gene_mass > 1.0 THEN (o.gene_mass - 1.0) * 0.35 ELSE 0 END
        + CASE WHEN o.gene_strength > 1.0 THEN (o.gene_strength - 1.0) * 0.10 ELSE 0 END
    ) AS effective_speed,
    o.gene_metabolism
        + CASE WHEN o.gene_speed > 1.0 THEN (o.gene_speed - 1.0) * 0.05 ELSE 0 END
        + CASE WHEN o.gene_mass > 1.0 THEN (o.gene_mass - 1.0) * 0.08 ELSE 0 END AS estimated_tick_cost,
    o.born_tick
FROM life.organism AS o
JOIN life.simulation AS s
    ON s.simulation_id = o.simulation_id
WHERE o.simulation_id = @simulation_id
  AND o.alive = 1
ORDER BY o.generation DESC, o.energy DESC, o.organism_id;


/*==============================================================================
    4. NASCIMENTOS E MORTES POR TICK
==============================================================================*/

;WITH births AS
(
    SELECT
        born_tick AS tick_no,
        COUNT(*) AS births
    FROM life.organism
    WHERE simulation_id = @simulation_id
    GROUP BY born_tick
),
deaths AS
(
    SELECT
        died_tick AS tick_no,
        COUNT(*) AS deaths
    FROM life.organism
    WHERE simulation_id = @simulation_id
      AND died_tick IS NOT NULL
    GROUP BY died_tick
)
SELECT
    COALESCE(b.tick_no, d.tick_no) AS tick_no,
    ISNULL(b.births, 0) AS births,
    ISNULL(d.deaths, 0) AS deaths,
    ISNULL(b.births, 0) - ISNULL(d.deaths, 0) AS net_growth
FROM births AS b
FULL JOIN deaths AS d
    ON b.tick_no = d.tick_no
ORDER BY tick_no;


/*==============================================================================
    5. EVOLUCAO DOS GENES POR GERACAO
==============================================================================*/

SELECT
    generation,
    COUNT(*) AS organisms,

    AVG(gene_speed) AS avg_speed,
    MIN(gene_speed) AS min_speed,
    MAX(gene_speed) AS max_speed,

    AVG(gene_metabolism) AS avg_metabolism,
    MIN(gene_metabolism) AS min_metabolism,
    MAX(gene_metabolism) AS max_metabolism,

    AVG(gene_reproduction) AS avg_reproduction,
    MIN(gene_reproduction) AS min_reproduction,
    MAX(gene_reproduction) AS max_reproduction,

    AVG(gene_strength) AS avg_strength,
    MIN(gene_strength) AS min_strength,
    MAX(gene_strength) AS max_strength,

    AVG(gene_mass) AS avg_mass,
    MIN(gene_mass) AS min_mass,
    MAX(gene_mass) AS max_mass,

    AVG(gene_strength * gene_mass) AS avg_effective_strength,
    AVG(gene_speed / (
        1.0
        + CASE WHEN gene_mass > 1.0 THEN (gene_mass - 1.0) * 0.35 ELSE 0 END
        + CASE WHEN gene_strength > 1.0 THEN (gene_strength - 1.0) * 0.10 ELSE 0 END
    )) AS avg_effective_speed
FROM life.organism
WHERE simulation_id = @simulation_id
GROUP BY generation
ORDER BY generation;


/*==============================================================================
    6. EVOLUCAO DOS GENES APENAS ENTRE OS SOBREVIVENTES
==============================================================================*/

SELECT
    o.generation,
    COUNT(*) AS survivors,
    SUM(CASE WHEN o.age >= s.min_reproduction_age THEN 1 ELSE 0 END) AS mature_survivors,
    SUM(CASE
            WHEN o.age >= s.min_reproduction_age
             AND o.energy >= o.gene_reproduction
                THEN 1
            ELSE 0
        END) AS ready_to_reproduce,

    AVG(o.gene_speed) AS avg_speed,
    AVG(o.gene_metabolism) AS avg_metabolism,
    AVG(o.gene_reproduction) AS avg_reproduction,
    AVG(o.gene_strength) AS avg_strength,
    AVG(o.gene_mass) AS avg_mass,
    AVG(o.gene_strength * o.gene_mass) AS avg_effective_strength,
    AVG(o.gene_speed / (
        1.0
        + CASE WHEN o.gene_mass > 1.0 THEN (o.gene_mass - 1.0) * 0.35 ELSE 0 END
        + CASE WHEN o.gene_strength > 1.0 THEN (o.gene_strength - 1.0) * 0.10 ELSE 0 END
    )) AS avg_effective_speed,

    AVG(o.energy) AS avg_energy,
    AVG(CONVERT(DECIMAL(18,4), o.age)) AS avg_age
FROM life.organism AS o
JOIN life.simulation AS s
    ON s.simulation_id = o.simulation_id
WHERE o.simulation_id = @simulation_id
  AND o.alive = 1
GROUP BY o.generation
ORDER BY o.generation;


/*==============================================================================
    7. QUAIS ORGANISMOS MAIS SE REPRODUZIRAM?
==============================================================================*/

SELECT TOP (50)
    p.organism_id,
    p.parent_organism_id,
    p.generation,
    p.alive,
    p.age,
    p.energy,

    p.gene_speed,
    p.gene_metabolism,
    p.gene_reproduction,
    p.gene_strength,
    p.gene_mass,
    p.gene_strength * p.gene_mass AS effective_strength,

    COUNT(c.organism_id) AS direct_children
FROM life.organism AS p
LEFT JOIN life.organism AS c
    ON c.parent_organism_id = p.organism_id
   AND c.simulation_id = p.simulation_id
WHERE p.simulation_id = @simulation_id
GROUP BY
    p.organism_id,
    p.parent_organism_id,
    p.generation,
    p.alive,
    p.age,
    p.energy,
    p.gene_speed,
    p.gene_metabolism,
    p.gene_reproduction,
    p.gene_strength,
    p.gene_mass
ORDER BY
    direct_children DESC,
    p.generation DESC;


/*==============================================================================
    8. DISTRIBUICAO DA POPULACAO ATUAL POR GERACAO
==============================================================================*/

SELECT
    o.generation,
    COUNT(*) AS population,
    SUM(CASE WHEN o.age >= s.min_reproduction_age THEN 1 ELSE 0 END) AS mature_population,
    SUM(CASE
            WHEN o.age >= s.min_reproduction_age
             AND o.energy >= o.gene_reproduction
                THEN 1
            ELSE 0
        END) AS ready_to_reproduce,
    AVG(o.energy) AS avg_energy,
    AVG(CONVERT(DECIMAL(18,4), o.age)) AS avg_age,
    AVG(o.gene_speed) AS avg_speed,
    AVG(o.gene_metabolism) AS avg_metabolism,
    AVG(o.gene_reproduction) AS avg_reproduction,
    AVG(o.gene_strength) AS avg_strength,
    AVG(o.gene_mass) AS avg_mass,
    AVG(o.gene_strength * o.gene_mass) AS avg_effective_strength,
    AVG(o.gene_speed / (
        1.0
        + CASE WHEN o.gene_mass > 1.0 THEN (o.gene_mass - 1.0) * 0.35 ELSE 0 END
        + CASE WHEN o.gene_strength > 1.0 THEN (o.gene_strength - 1.0) * 0.10 ELSE 0 END
    )) AS avg_effective_speed
FROM life.organism AS o
JOIN life.simulation AS s
    ON s.simulation_id = o.simulation_id
WHERE o.simulation_id = @simulation_id
  AND o.alive = 1
GROUP BY o.generation
ORDER BY o.generation;


/*==============================================================================
    9. ESTATISTICAS GERAIS DE TODA A HISTORIA DA POPULACAO
==============================================================================*/

SELECT
    COUNT(*) AS organisms_ever_born,
    SUM(CASE WHEN alive = 1 THEN 1 ELSE 0 END) AS alive_now,
    SUM(CASE WHEN alive = 0 THEN 1 ELSE 0 END) AS dead,
    MAX(generation) AS max_generation,
    MIN(born_tick) AS first_birth_tick,
    MAX(born_tick) AS latest_birth_tick,

    AVG(CONVERT(DECIMAL(18,4), CASE
        WHEN died_tick IS NOT NULL THEN died_tick - born_tick
        ELSE NULL
    END)) AS avg_lifespan_dead,

    MAX(CASE
        WHEN died_tick IS NOT NULL THEN died_tick - born_tick
    END) AS max_lifespan_dead
FROM life.organism
WHERE simulation_id = @simulation_id;


/*==============================================================================
    10. RECURSOS ATUAIS NO MAPA
==============================================================================*/

SELECT
    resource_id,
    x,
    y,
    energy,
    created_tick
FROM life.resource
WHERE simulation_id = @simulation_id
ORDER BY x, y;


/*==============================================================================
    11. PRESSAO DE COMPETICAO POR CELULA

    Mostra concentracao atual de organismos por tile.
==============================================================================*/

SELECT TOP (50)
    x,
    y,
    COUNT(*) AS organisms_on_cell,
    AVG(energy) AS avg_energy,
    AVG(gene_strength) AS avg_strength,
    MAX(gene_strength) AS max_strength,
    AVG(gene_mass) AS avg_mass,
    AVG(gene_strength * gene_mass) AS avg_effective_strength,
    MAX(gene_strength * gene_mass) AS max_effective_strength
FROM life.organism
WHERE simulation_id = @simulation_id
  AND alive = 1
GROUP BY x, y
ORDER BY organisms_on_cell DESC, max_strength DESC;


/*==============================================================================
    12. RECURSOS QUE JA NASCERAM EM CELULAS OCUPADAS

    Esses tiles devem gerar disputa no proximo tick.
==============================================================================*/

SELECT TOP (100)
    r.resource_id,
    r.x,
    r.y,
    r.energy,
    r.created_tick,
    COUNT(o.organism_id) AS organisms_on_resource_cell,
    AVG(o.gene_strength) AS avg_contender_strength,
    MAX(o.gene_strength) AS max_contender_strength,
    AVG(o.gene_mass) AS avg_contender_mass,
    AVG(o.gene_strength * o.gene_mass) AS avg_effective_strength,
    MAX(o.gene_strength * o.gene_mass) AS max_effective_strength
FROM life.resource AS r
JOIN life.organism AS o
    ON o.simulation_id = r.simulation_id
   AND o.x = r.x
   AND o.y = r.y
   AND o.alive = 1
WHERE r.simulation_id = @simulation_id
GROUP BY
    r.resource_id,
    r.x,
    r.y,
    r.energy,
    r.created_tick
ORDER BY organisms_on_resource_cell DESC, max_contender_strength DESC;


/*==============================================================================
    13. DISTANCIA DOS VIVOS ATE A COMIDA MAIS PROXIMA

    Mede se a percepcao de comida esta deixando organismos perto dos recursos.
==============================================================================*/

;WITH nearest_food AS
(
    SELECT
        o.organism_id,
        o.generation,
        o.energy,
        o.age,
        o.gene_speed,
        o.gene_strength,
        o.gene_mass,
        nearest.distance_to_food
    FROM life.organism AS o
    OUTER APPLY
    (
        SELECT TOP (1)
            ABS(r.x - o.x) + ABS(r.y - o.y) AS distance_to_food
        FROM life.resource AS r
        WHERE r.simulation_id = o.simulation_id
        ORDER BY ABS(r.x - o.x) + ABS(r.y - o.y), r.resource_id
    ) AS nearest
    WHERE o.simulation_id = @simulation_id
      AND o.alive = 1
)
SELECT
    COUNT(*) AS alive_now,
    AVG(CONVERT(DECIMAL(18,4), distance_to_food)) AS avg_distance_to_food,
    MIN(distance_to_food) AS min_distance_to_food,
    MAX(distance_to_food) AS max_distance_to_food,
    SUM(CASE WHEN distance_to_food = 0 THEN 1 ELSE 0 END) AS standing_on_food,
    SUM(CASE WHEN distance_to_food <= 3 THEN 1 ELSE 0 END) AS within_3_tiles,
    SUM(CASE WHEN distance_to_food <= 6 THEN 1 ELSE 0 END) AS within_6_tiles
FROM nearest_food;


/*==============================================================================
    14. MATURIDADE REPRODUTIVA ATUAL

    Se mature_but_not_ready cresce, falta energia.
    Se immature cresce, a idade minima esta segurando o takeoff.
==============================================================================*/

SELECT
    SUM(CASE WHEN o.age < s.min_reproduction_age THEN 1 ELSE 0 END) AS immature,
    SUM(CASE
            WHEN o.age >= s.min_reproduction_age
             AND o.energy < o.gene_reproduction
                THEN 1
            ELSE 0
        END) AS mature_but_not_ready,
    SUM(CASE
            WHEN o.age >= s.min_reproduction_age
             AND o.energy >= o.gene_reproduction
                THEN 1
            ELSE 0
        END) AS ready_to_reproduce,
    AVG(CASE
            WHEN o.age < s.min_reproduction_age
                THEN CONVERT(DECIMAL(18,4), o.energy)
        END) AS avg_energy_immature,
    AVG(CASE
            WHEN o.age >= s.min_reproduction_age
                THEN CONVERT(DECIMAL(18,4), o.energy)
        END) AS avg_energy_mature,
    AVG(o.gene_mass) AS avg_mass,
    AVG(o.gene_strength * o.gene_mass) AS avg_effective_strength
FROM life.organism AS o
JOIN life.simulation AS s
    ON s.simulation_id = o.simulation_id
WHERE o.simulation_id = @simulation_id
  AND o.alive = 1;
