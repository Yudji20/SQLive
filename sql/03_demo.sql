DECLARE @simulation_id int;

EXEC life.reset_world
    @name = N'SQLife - primeiro experimento',
    @width = 60,
    @height = 60,
    @initial_organisms = 80,
    @initial_resources = 350,
    @food_energy = 10.0,
    @food_sense_radius = 6,
    @mutation_rate = 0.080000,
    @mutation_strength = 0.120000,
    @min_reproduction_age = 20,
    @max_age = 220,
    @simulation_id = @simulation_id OUTPUT;

EXEC life.run @simulation_id = @simulation_id, @ticks = 300;

SELECT *
FROM life.v_metrics_recent
WHERE simulation_name = N'SQLife - primeiro experimento'
ORDER BY tick_no;

SELECT TOP (20)
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
    gene_mass
FROM life.v_alive_organisms
WHERE simulation_id = @simulation_id
ORDER BY generation DESC, energy DESC;

SELECT
    generation,
    COUNT(*) AS snapshots,
    COUNT(DISTINCT organism_id) AS organisms_seen,
    AVG(gene_speed) AS avg_speed,
    AVG(gene_metabolism) AS avg_metabolism,
    AVG(gene_reproduction) AS avg_reproduction,
    AVG(gene_strength) AS avg_strength,
    AVG(gene_mass) AS avg_mass
FROM life.organism_history
WHERE simulation_id = @simulation_id
GROUP BY generation
ORDER BY generation;
