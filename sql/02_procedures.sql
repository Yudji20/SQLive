CREATE OR ALTER PROCEDURE life.reset_world
    @name sysname = N'SQLife demo',
    @width int = 100,
    @height int = 100,
    @initial_organisms int = 100,
    @initial_resources int = 500,
    @food_energy decimal(10,4) = 10.0,
    @food_sense_radius int = 6,
    @mutation_rate decimal(9,6) = 0.080000,
    @mutation_strength decimal(9,6) = 0.150000,
    @min_reproduction_age int = 20,
    @max_age int = 250,
    @simulation_id int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @width <= 0 OR @height <= 0 THROW 50001, 'World dimensions must be positive.', 1;
    IF @initial_organisms < 0 OR @initial_resources < 0 THROW 50002, 'Initial counts cannot be negative.', 1;
    IF @food_energy <= 0 THROW 50003, 'Food energy must be positive.', 1;
    IF @food_sense_radius < 0 THROW 50004, 'Food sense radius cannot be negative.', 1;
    IF @mutation_rate < 0 OR @mutation_rate > 1 THROW 50005, 'Mutation rate must be between 0 and 1.', 1;
    IF @mutation_strength < 0 THROW 50006, 'Mutation strength cannot be negative.', 1;
    IF @min_reproduction_age < 0 THROW 50007, 'Minimum reproduction age cannot be negative.', 1;
    IF @max_age <= 0 THROW 50008, 'Max age must be positive.', 1;
    IF @min_reproduction_age >= @max_age THROW 50009, 'Minimum reproduction age must be lower than max age.', 1;

    BEGIN TRANSACTION;

    INSERT life.simulation
    (
        name,
        width,
        height,
        food_target,
        food_energy,
        food_sense_radius,
        mutation_rate,
        mutation_strength,
        min_reproduction_age,
        max_age
    )
    VALUES
    (
        @name,
        @width,
        @height,
        @initial_resources,
        @food_energy,
        @food_sense_radius,
        @mutation_rate,
        @mutation_strength,
        @min_reproduction_age,
        @max_age
    );

    SET @simulation_id = CONVERT(int, SCOPE_IDENTITY());

    ;WITH n AS
    (
        SELECT TOP (@initial_organisms)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
        FROM sys.all_objects AS a
        CROSS JOIN sys.all_objects AS b
    )
    INSERT life.organism
    (
        simulation_id,
        parent_organism_id,
        generation,
        x,
        y,
        energy,
        gene_speed,
        gene_metabolism,
        gene_reproduction,
        gene_strength,
        gene_mass,
        born_tick
    )
    SELECT
        @simulation_id,
        NULL,
        0,
        1 + ABS(CHECKSUM(NEWID())) % @width,
        1 + ABS(CHECKSUM(NEWID())) % @height,
        20.0 + (ABS(CHECKSUM(NEWID())) % 1000) / 100.0,
        1.0 + (ABS(CHECKSUM(NEWID())) % 300) / 100.0,
        0.5 + (ABS(CHECKSUM(NEWID())) % 250) / 100.0,
        25.0 + (ABS(CHECKSUM(NEWID())) % 2500) / 100.0,
        0.5 + (ABS(CHECKSUM(NEWID())) % 250) / 100.0,
        0.75 + (ABS(CHECKSUM(NEWID())) % 176) / 100.0,
        0
    FROM n;

    ;WITH n AS
    (
        SELECT TOP (@initial_resources)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
        FROM sys.all_objects AS a
        CROSS JOIN sys.all_objects AS b
    )
    INSERT life.resource (simulation_id, x, y, energy, created_tick)
    SELECT
        @simulation_id,
        1 + ABS(CHECKSUM(NEWID())) % @width,
        1 + ABS(CHECKSUM(NEWID())) % @height,
        @food_energy,
        0
    FROM n;

    EXEC life.capture_metrics @simulation_id;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE life.capture_metrics
    @simulation_id int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tick_no int =
    (
        SELECT tick_no
        FROM life.simulation
        WHERE simulation_id = @simulation_id
    );

    IF @tick_no IS NULL THROW 50010, 'Simulation not found.', 1;

    INSERT life.metrics
    (
        simulation_id,
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
        avg_gene_mass
    )
    SELECT
        @simulation_id,
        @tick_no,
        CONVERT(int, COUNT_BIG(CASE WHEN o.alive = 1 THEN 1 END)),
        (SELECT CONVERT(int, COUNT_BIG(*)) FROM life.resource AS r WHERE r.simulation_id = @simulation_id),
        AVG(CASE WHEN o.alive = 1 THEN o.energy END),
        AVG(CASE WHEN o.alive = 1 THEN CONVERT(decimal(10,4), o.age) END),
        AVG(CASE WHEN o.alive = 1 THEN CONVERT(decimal(10,4), o.generation) END),
        AVG(CASE WHEN o.alive = 1 THEN o.gene_speed END),
        AVG(CASE WHEN o.alive = 1 THEN o.gene_metabolism END),
        AVG(CASE WHEN o.alive = 1 THEN o.gene_reproduction END),
        AVG(CASE WHEN o.alive = 1 THEN o.gene_strength END),
        AVG(CASE WHEN o.alive = 1 THEN o.gene_mass END)
    FROM life.organism AS o
    WHERE o.simulation_id = @simulation_id
    HAVING NOT EXISTS
    (
        SELECT 1
        FROM life.metrics AS m
        WHERE m.simulation_id = @simulation_id
          AND m.tick_no = @tick_no
    );
END;
GO

CREATE OR ALTER PROCEDURE life.execute_tick
    @simulation_id int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @width int,
        @height int,
        @tick_no int,
        @food_target int,
        @food_energy decimal(10,4),
        @food_sense_radius int,
        @mutation_rate decimal(9,6),
        @mutation_strength decimal(9,6),
        @min_reproduction_age int,
        @max_age int;

    SELECT
        @width = width,
        @height = height,
        @tick_no = tick_no + 1,
        @food_target = food_target,
        @food_energy = food_energy,
        @food_sense_radius = food_sense_radius,
        @mutation_rate = mutation_rate,
        @mutation_strength = mutation_strength,
        @min_reproduction_age = min_reproduction_age,
        @max_age = max_age
    FROM life.simulation
    WHERE simulation_id = @simulation_id;

    IF @width IS NULL THROW 50020, 'Simulation not found.', 1;

    BEGIN TRANSACTION;

    UPDATE life.simulation
    SET tick_no = @tick_no
    WHERE simulation_id = @simulation_id;

    UPDATE o
    SET
        age = age + 1,
        energy = energy
            - gene_metabolism
            - CASE
                WHEN gene_speed > 1.0 THEN (gene_speed - 1.0) * 0.05
                ELSE 0
            END
            - CASE
                WHEN gene_mass > 1.0 THEN (gene_mass - 1.0) * 0.08
                ELSE 0
            END
    FROM life.organism AS o
    WHERE o.simulation_id = @simulation_id
      AND o.alive = 1;

    UPDATE o
    SET
        x =
            CASE
                WHEN o.x + move.dx < 1 THEN 1
                WHEN o.x + move.dx > @width THEN @width
                ELSE o.x + move.dx
            END,
        y =
            CASE
                WHEN o.y + move.dy < 1 THEN 1
                WHEN o.y + move.dy > @height THEN @height
                ELSE o.y + move.dy
            END
    FROM life.organism AS o
    CROSS APPLY
    (
        SELECT
            1.0
            + CASE
                WHEN o.gene_mass > 1.0 THEN (o.gene_mass - 1.0) * 0.35
                ELSE 0
            END
            + CASE
                WHEN o.gene_strength > 1.0 THEN (o.gene_strength - 1.0) * 0.10
                ELSE 0
            END AS drag_factor
    ) AS drag
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN o.gene_speed / drag.drag_factor < 1.0 THEN 1
                ELSE CONVERT(int, ROUND(o.gene_speed / drag.drag_factor, 0))
            END AS speed
    ) AS speed
    OUTER APPLY
    (
        SELECT TOP (1)
            r.x AS target_x,
            r.y AS target_y
        FROM life.resource AS r
        WHERE r.simulation_id = o.simulation_id
          AND ABS(r.x - o.x) + ABS(r.y - o.y) <= @food_sense_radius
        ORDER BY
            ABS(r.x - o.x) + ABS(r.y - o.y),
            CHECKSUM(NEWID())
    ) AS target
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN target.target_x IS NULL
                    THEN (ABS(CHECKSUM(NEWID())) % (2 * speed.speed + 1)) - speed.speed
                WHEN target.target_x > o.x
                    THEN IIF(target.target_x - o.x > speed.speed, speed.speed, target.target_x - o.x)
                WHEN target.target_x < o.x
                    THEN -IIF(o.x - target.target_x > speed.speed, speed.speed, o.x - target.target_x)
                ELSE 0
            END AS dx,
            CASE
                WHEN target.target_y IS NULL
                    THEN (ABS(CHECKSUM(NEWID())) % (2 * speed.speed + 1)) - speed.speed
                WHEN target.target_y > o.y
                    THEN IIF(target.target_y - o.y > speed.speed, speed.speed, target.target_y - o.y)
                WHEN target.target_y < o.y
                    THEN -IIF(o.y - target.target_y > speed.speed, speed.speed, o.y - target.target_y)
                ELSE 0
            END AS dy
    ) AS move
    WHERE o.simulation_id = @simulation_id
      AND o.alive = 1;

    DECLARE @meals TABLE
    (
        organism_id bigint NOT NULL PRIMARY KEY,
        resource_id bigint NOT NULL UNIQUE,
        energy decimal(10,4) NOT NULL
    );

    ;WITH contenders AS
    (
        SELECT
            o.organism_id,
            r.resource_id,
            r.energy,
            ROW_NUMBER() OVER
            (
                PARTITION BY r.resource_id
                ORDER BY o.gene_strength * o.gene_mass * RAND(CHECKSUM(NEWID())) DESC,
                         o.energy DESC,
                         o.organism_id
            ) AS contender_rank,
            o.gene_strength,
            o.gene_mass
        FROM life.organism AS o
        JOIN life.resource AS r
            ON r.simulation_id = o.simulation_id
           AND r.x = o.x
           AND r.y = o.y
        WHERE o.simulation_id = @simulation_id
          AND o.alive = 1
    ),
    resource_winners AS
    (
        SELECT organism_id, resource_id, energy
        FROM contenders
        WHERE contender_rank = 1
    ),
    meal AS
    (
        SELECT
            organism_id,
            resource_id,
            energy,
            ROW_NUMBER() OVER
            (
                PARTITION BY organism_id
                ORDER BY energy DESC, resource_id
            ) AS organism_resource_rank
        FROM resource_winners
    )
    INSERT @meals (organism_id, resource_id, energy)
    SELECT organism_id, resource_id, energy
    FROM meal
    WHERE organism_resource_rank = 1;

    UPDATE o
    SET energy = o.energy + m.energy
    FROM life.organism AS o
    JOIN @meals AS m
        ON m.organism_id = o.organism_id;

    DELETE r
    FROM life.resource AS r
    JOIN @meals AS m
        ON m.resource_id = r.resource_id
      AND r.simulation_id = @simulation_id;

    DECLARE @parents TABLE
    (
        organism_id bigint NOT NULL PRIMARY KEY
    );

    INSERT @parents (organism_id)
    SELECT o.organism_id
    FROM life.organism AS o
    WHERE o.simulation_id = @simulation_id
      AND o.alive = 1
      AND o.age >= @min_reproduction_age
      AND o.energy >= o.gene_reproduction;

    INSERT life.organism
    (
        simulation_id,
        parent_organism_id,
        generation,
        x,
        y,
        energy,
        gene_speed,
        gene_metabolism,
        gene_reproduction,
        gene_strength,
        gene_mass,
        born_tick
    )
    SELECT
        o.simulation_id,
        o.organism_id,
        o.generation + 1,
        CASE
            WHEN o.x + birth.dx < 1 THEN 1
            WHEN o.x + birth.dx > @width THEN @width
            ELSE o.x + birth.dx
        END,
        CASE
            WHEN o.y + birth.dy < 1 THEN 1
            WHEN o.y + birth.dy > @height THEN @height
            ELSE o.y + birth.dy
        END,
        o.energy / 2.0,
        CASE WHEN mutation.mutate_speed = 1
            THEN IIF(o.gene_speed + mutation.speed_delta < 0.1, 0.1, o.gene_speed + mutation.speed_delta)
            ELSE o.gene_speed
        END,
        CASE WHEN mutation.mutate_metabolism = 1
            THEN IIF(o.gene_metabolism + mutation.metabolism_delta < 0.1, 0.1, o.gene_metabolism + mutation.metabolism_delta)
            ELSE o.gene_metabolism
        END,
        CASE WHEN mutation.mutate_reproduction = 1
            THEN IIF(o.gene_reproduction + mutation.reproduction_delta < 1.0, 1.0, o.gene_reproduction + mutation.reproduction_delta)
            ELSE o.gene_reproduction
        END,
        CASE WHEN mutation.mutate_strength = 1
            THEN IIF(o.gene_strength + mutation.strength_delta < 0.1, 0.1, o.gene_strength + mutation.strength_delta)
            ELSE o.gene_strength
        END,
        CASE WHEN mutation.mutate_mass = 1
            THEN IIF(o.gene_mass + mutation.mass_delta < 0.25, 0.25, o.gene_mass + mutation.mass_delta)
            ELSE o.gene_mass
        END,
        @tick_no
    FROM life.organism AS o
    JOIN @parents AS p
        ON p.organism_id = o.organism_id
    CROSS APPLY
    (
        SELECT
            (ABS(CHECKSUM(NEWID())) % 3) - 1 AS dx,
            (ABS(CHECKSUM(NEWID())) % 3) - 1 AS dy
    ) AS birth
    CROSS APPLY
    (
        SELECT
            CASE WHEN RAND(CHECKSUM(NEWID())) < @mutation_rate THEN 1 ELSE 0 END AS mutate_speed,
            CASE WHEN RAND(CHECKSUM(NEWID())) < @mutation_rate THEN 1 ELSE 0 END AS mutate_metabolism,
            CASE WHEN RAND(CHECKSUM(NEWID())) < @mutation_rate THEN 1 ELSE 0 END AS mutate_reproduction,
            CASE WHEN RAND(CHECKSUM(NEWID())) < @mutation_rate THEN 1 ELSE 0 END AS mutate_strength,
            CASE WHEN RAND(CHECKSUM(NEWID())) < @mutation_rate THEN 1 ELSE 0 END AS mutate_mass,
            ((RAND(CHECKSUM(NEWID())) * 2.0) - 1.0) * @mutation_strength * o.gene_speed AS speed_delta,
            ((RAND(CHECKSUM(NEWID())) * 2.0) - 1.0) * @mutation_strength * o.gene_metabolism AS metabolism_delta,
            ((RAND(CHECKSUM(NEWID())) * 2.0) - 1.0) * @mutation_strength * o.gene_reproduction AS reproduction_delta,
            ((RAND(CHECKSUM(NEWID())) * 2.0) - 1.0) * @mutation_strength * o.gene_strength AS strength_delta,
            ((RAND(CHECKSUM(NEWID())) * 2.0) - 1.0) * @mutation_strength * o.gene_mass AS mass_delta
    ) AS mutation
    WHERE o.simulation_id = @simulation_id
      AND o.alive = 1;

    UPDATE o
    SET energy = energy / 2.0
    FROM life.organism AS o
    JOIN @parents AS p
        ON p.organism_id = o.organism_id
    WHERE o.simulation_id = @simulation_id
      AND o.alive = 1;

    UPDATE o
    SET
        alive = 0,
        died_tick = @tick_no
    FROM life.organism AS o
    WHERE o.simulation_id = @simulation_id
      AND o.alive = 1
      AND (o.energy <= 0 OR o.age >= @max_age);

    DECLARE @current_resources int =
    (
        SELECT COUNT(*)
        FROM life.resource
        WHERE simulation_id = @simulation_id
    );

    DECLARE @resources_to_spawn int =
        CASE
            WHEN @food_target > @current_resources THEN @food_target - @current_resources
            ELSE 0
        END;

    ;WITH n AS
    (
        SELECT TOP (@resources_to_spawn)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
        FROM sys.all_objects AS a
        CROSS JOIN sys.all_objects AS b
    )
    INSERT life.resource (simulation_id, x, y, energy, created_tick)
    SELECT
        @simulation_id,
        1 + ABS(CHECKSUM(NEWID())) % @width,
        1 + ABS(CHECKSUM(NEWID())) % @height,
        @food_energy,
        @tick_no
    FROM n;

    INSERT life.organism_history
    (
        tick_no,
        organism_id,
        simulation_id,
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
        gene_mass,
        alive
    )
    SELECT
        @tick_no,
        organism_id,
        simulation_id,
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
        gene_mass,
        alive
    FROM life.organism
    WHERE simulation_id = @simulation_id;

    EXEC life.capture_metrics @simulation_id;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE life.run
    @simulation_id int,
    @ticks int = 100
AS
BEGIN
    SET NOCOUNT ON;

    IF @ticks < 0 THROW 50030, 'Ticks cannot be negative.', 1;

    DECLARE @i int = 0;

    WHILE @i < @ticks
    BEGIN
        EXEC life.execute_tick @simulation_id;
        SET @i += 1;
    END;
END;
GO

CREATE OR ALTER PROCEDURE life.show_lineage
    @organism_id bigint
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH lineage AS
    (
        SELECT
            o.organism_id,
            o.parent_organism_id,
            o.generation,
            o.energy,
            o.age,
            o.gene_speed,
            o.gene_metabolism,
            o.gene_reproduction,
            o.gene_strength,
            o.gene_mass,
            0 AS distance_from_target
        FROM life.organism AS o
        WHERE o.organism_id = @organism_id

        UNION ALL

        SELECT
            parent.organism_id,
            parent.parent_organism_id,
            parent.generation,
            parent.energy,
            parent.age,
            parent.gene_speed,
            parent.gene_metabolism,
            parent.gene_reproduction,
            parent.gene_strength,
            parent.gene_mass,
            child.distance_from_target + 1
        FROM lineage AS child
        JOIN life.organism AS parent
            ON parent.organism_id = child.parent_organism_id
    )
    SELECT
        organism_id,
        parent_organism_id,
        generation,
        energy,
        age,
        gene_speed,
        gene_metabolism,
        gene_reproduction,
        gene_strength,
        gene_mass,
        distance_from_target
    FROM lineage
    ORDER BY distance_from_target DESC;
END;
GO
