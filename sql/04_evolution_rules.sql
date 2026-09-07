IF COL_LENGTH('life.simulation', 'min_reproduction_age') IS NULL
BEGIN
    ALTER TABLE life.simulation
    ADD min_reproduction_age int NOT NULL
        CONSTRAINT df_life_simulation_min_reproduction_age DEFAULT (20) WITH VALUES;
END;
GO

IF COL_LENGTH('life.simulation', 'food_sense_radius') IS NULL
BEGIN
    ALTER TABLE life.simulation
    ADD food_sense_radius int NOT NULL
        CONSTRAINT df_life_simulation_food_sense_radius DEFAULT (6) WITH VALUES;
END;
GO

IF COL_LENGTH('life.organism', 'gene_strength') IS NULL
BEGIN
    ALTER TABLE life.organism
    ADD gene_strength decimal(10,4) NOT NULL
        CONSTRAINT df_life_organism_gene_strength DEFAULT (1.0) WITH VALUES;
END;
GO

IF COL_LENGTH('life.organism', 'gene_mass') IS NULL
BEGIN
    ALTER TABLE life.organism
    ADD gene_mass decimal(10,4) NOT NULL
        CONSTRAINT df_life_organism_gene_mass DEFAULT (1.0) WITH VALUES;
END;
GO

IF COL_LENGTH('life.organism_history', 'gene_strength') IS NULL
BEGIN
    ALTER TABLE life.organism_history
    ADD gene_strength decimal(10,4) NOT NULL
        CONSTRAINT df_life_organism_history_gene_strength DEFAULT (1.0) WITH VALUES;
END;
GO

IF COL_LENGTH('life.organism_history', 'gene_mass') IS NULL
BEGIN
    ALTER TABLE life.organism_history
    ADD gene_mass decimal(10,4) NOT NULL
        CONSTRAINT df_life_organism_history_gene_mass DEFAULT (1.0) WITH VALUES;
END;
GO

IF COL_LENGTH('life.metrics', 'avg_gene_strength') IS NULL
BEGIN
    ALTER TABLE life.metrics
    ADD avg_gene_strength decimal(10,4) NULL;
END;
GO

IF COL_LENGTH('life.metrics', 'avg_gene_mass') IS NULL
BEGIN
    ALTER TABLE life.metrics
    ADD avg_gene_mass decimal(10,4) NULL;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'ck_life_simulation_reproduction_age'
      AND parent_object_id = OBJECT_ID(N'life.simulation')
)
BEGIN
    ALTER TABLE life.simulation
    DROP CONSTRAINT ck_life_simulation_reproduction_age;
END;
GO

ALTER TABLE life.simulation
ADD CONSTRAINT ck_life_simulation_reproduction_age CHECK (min_reproduction_age >= 0 AND min_reproduction_age < max_age);
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'ck_life_simulation_food_sense'
      AND parent_object_id = OBJECT_ID(N'life.simulation')
)
BEGIN
    ALTER TABLE life.simulation
    DROP CONSTRAINT ck_life_simulation_food_sense;
END;
GO

ALTER TABLE life.simulation
ADD CONSTRAINT ck_life_simulation_food_sense CHECK (food_sense_radius >= 0);
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'ck_life_organism_strength'
      AND parent_object_id = OBJECT_ID(N'life.organism')
)
BEGIN
    ALTER TABLE life.organism
    ADD CONSTRAINT ck_life_organism_strength CHECK (gene_strength > 0);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'ck_life_organism_mass'
      AND parent_object_id = OBJECT_ID(N'life.organism')
)
BEGIN
    ALTER TABLE life.organism
    ADD CONSTRAINT ck_life_organism_mass CHECK (gene_mass > 0);
END;
GO

CREATE OR ALTER VIEW life.v_alive_organisms
AS
SELECT
    o.organism_id,
    o.simulation_id,
    s.name AS simulation_name,
    o.parent_organism_id,
    o.generation,
    o.x,
    o.y,
    o.energy,
    o.age,
    o.gene_speed,
    o.gene_metabolism,
    o.gene_reproduction,
    o.gene_strength,
    o.gene_mass,
    o.born_tick
FROM life.organism AS o
JOIN life.simulation AS s
    ON s.simulation_id = o.simulation_id
WHERE o.alive = 1;
GO

CREATE OR ALTER VIEW life.v_metrics_recent
AS
SELECT TOP (500)
    s.name AS simulation_name,
    m.tick_no,
    m.population,
    m.resources,
    m.avg_energy,
    m.avg_age,
    m.avg_generation,
    m.avg_gene_speed,
    m.avg_gene_metabolism,
    m.avg_gene_reproduction,
    m.avg_gene_strength,
    m.avg_gene_mass
FROM life.metrics AS m
JOIN life.simulation AS s
    ON s.simulation_id = m.simulation_id
ORDER BY m.simulation_id DESC, m.tick_no DESC;
GO
