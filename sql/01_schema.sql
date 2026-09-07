IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'life')
BEGIN
    EXEC(N'CREATE SCHEMA life');
END
GO

DROP VIEW IF EXISTS life.v_metrics_recent;
DROP VIEW IF EXISTS life.v_alive_organisms;
DROP TABLE IF EXISTS life.metrics;
DROP TABLE IF EXISTS life.resource;
DROP TABLE IF EXISTS life.organism_history;
DROP TABLE IF EXISTS life.organism;
DROP TABLE IF EXISTS life.simulation;
GO

CREATE TABLE life.simulation
(
    simulation_id int IDENTITY(1,1) NOT NULL CONSTRAINT pk_life_simulation PRIMARY KEY,
    name sysname NOT NULL,
    width int NOT NULL,
    height int NOT NULL,
    tick_no int NOT NULL CONSTRAINT df_life_simulation_tick_no DEFAULT (0),
    food_target int NOT NULL,
    food_energy decimal(10,4) NOT NULL,
    food_sense_radius int NOT NULL,
    mutation_rate decimal(9,6) NOT NULL,
    mutation_strength decimal(9,6) NOT NULL,
    min_reproduction_age int NOT NULL,
    max_age int NOT NULL,
    created_at datetime2(0) NOT NULL CONSTRAINT df_life_simulation_created_at DEFAULT (sysdatetime()),
    CONSTRAINT ck_life_simulation_size CHECK (width > 0 AND height > 0),
    CONSTRAINT ck_life_simulation_food CHECK (food_target >= 0 AND food_energy > 0),
    CONSTRAINT ck_life_simulation_food_sense CHECK (food_sense_radius >= 0),
    CONSTRAINT ck_life_simulation_mutation CHECK (mutation_rate BETWEEN 0 AND 1 AND mutation_strength >= 0),
    CONSTRAINT ck_life_simulation_reproduction_age CHECK (min_reproduction_age >= 0 AND min_reproduction_age < max_age),
    CONSTRAINT ck_life_simulation_max_age CHECK (max_age > 0)
);
GO

CREATE TABLE life.organism
(
    organism_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_life_organism PRIMARY KEY,
    simulation_id int NOT NULL,
    parent_organism_id bigint NULL,
    generation int NOT NULL,
    x int NOT NULL,
    y int NOT NULL,
    energy decimal(10,4) NOT NULL,
    age int NOT NULL CONSTRAINT df_life_organism_age DEFAULT (0),
    gene_speed decimal(10,4) NOT NULL,
    gene_metabolism decimal(10,4) NOT NULL,
    gene_reproduction decimal(10,4) NOT NULL,
    gene_strength decimal(10,4) NOT NULL,
    gene_mass decimal(10,4) NOT NULL,
    alive bit NOT NULL CONSTRAINT df_life_organism_alive DEFAULT (1),
    born_tick int NOT NULL,
    died_tick int NULL,
    CONSTRAINT fk_life_organism_simulation FOREIGN KEY (simulation_id) REFERENCES life.simulation(simulation_id),
    CONSTRAINT fk_life_organism_parent FOREIGN KEY (parent_organism_id) REFERENCES life.organism(organism_id),
    CONSTRAINT ck_life_organism_generation CHECK (generation >= 0),
    CONSTRAINT ck_life_organism_position CHECK (x >= 1 AND y >= 1),
    CONSTRAINT ck_life_organism_genes CHECK (gene_speed > 0 AND gene_metabolism > 0 AND gene_reproduction > 0 AND gene_strength > 0 AND gene_mass > 0)
);
GO

CREATE TABLE life.organism_history
(
    history_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_life_organism_history PRIMARY KEY,
    tick_no int NOT NULL,
    organism_id bigint NOT NULL,
    simulation_id int NOT NULL,
    parent_organism_id bigint NULL,
    generation int NOT NULL,
    x int NOT NULL,
    y int NOT NULL,
    energy decimal(10,4) NOT NULL,
    age int NOT NULL,
    gene_speed decimal(10,4) NOT NULL,
    gene_metabolism decimal(10,4) NOT NULL,
    gene_reproduction decimal(10,4) NOT NULL,
    gene_strength decimal(10,4) NOT NULL,
    gene_mass decimal(10,4) NOT NULL,
    alive bit NOT NULL
);
GO

CREATE TABLE life.resource
(
    resource_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_life_resource PRIMARY KEY,
    simulation_id int NOT NULL,
    x int NOT NULL,
    y int NOT NULL,
    energy decimal(10,4) NOT NULL,
    created_tick int NOT NULL,
    CONSTRAINT fk_life_resource_simulation FOREIGN KEY (simulation_id) REFERENCES life.simulation(simulation_id),
    CONSTRAINT ck_life_resource_position CHECK (x >= 1 AND y >= 1),
    CONSTRAINT ck_life_resource_energy CHECK (energy > 0)
);
GO

CREATE TABLE life.metrics
(
    simulation_id int NOT NULL,
    tick_no int NOT NULL,
    population int NOT NULL,
    resources int NOT NULL,
    avg_energy decimal(10,4) NULL,
    avg_age decimal(10,4) NULL,
    avg_generation decimal(10,4) NULL,
    avg_gene_speed decimal(10,4) NULL,
    avg_gene_metabolism decimal(10,4) NULL,
    avg_gene_reproduction decimal(10,4) NULL,
    avg_gene_strength decimal(10,4) NULL,
    avg_gene_mass decimal(10,4) NULL,
    created_at datetime2(0) NOT NULL CONSTRAINT df_life_metrics_created_at DEFAULT (sysdatetime()),
    CONSTRAINT pk_life_metrics PRIMARY KEY (simulation_id, tick_no),
    CONSTRAINT fk_life_metrics_simulation FOREIGN KEY (simulation_id) REFERENCES life.simulation(simulation_id)
);
GO

CREATE INDEX ix_life_organism_alive ON life.organism(simulation_id, alive, x, y);
CREATE INDEX ix_life_resource_position ON life.resource(simulation_id, x, y);
CREATE INDEX ix_life_history_generation ON life.organism_history(simulation_id, generation);
GO

CREATE VIEW life.v_alive_organisms
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

CREATE VIEW life.v_metrics_recent
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
