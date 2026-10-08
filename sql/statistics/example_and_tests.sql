SET NOCOUNT ON;

-- Exemplo equivalente ao GROUP BY class da tabela de cartoes.
DECLARE @DadosFicticios TABLE
(
    Id int NOT NULL PRIMARY KEY,
    Class int NOT NULL
);

INSERT INTO @DadosFicticios (Id, Class)
VALUES (1, 0), (2, 0), (3, 0), (4, 0), (5, 0),
       (6, 0), (7, 0), (8, 0), (9, 1), (10, 1);

DECLARE @Frequencias dbo.FrequenciasClasse;

INSERT INTO @Frequencias (Qtd)
SELECT COUNT_BIG(*)
FROM @DadosFicticios
GROUP BY Class;

SELECT Class, COUNT_BIG(*) AS Qtd
FROM @DadosFicticios
GROUP BY Class
ORDER BY Class;

SELECT dbo.fn_gini(@Frequencias) AS GINI,
       dbo.fn_entropia(@Frequencias) AS ENTROPIA;
-- Esperado: GINI = 0.32; ENTROPIA = 0.7219280948873623.

DECLARE @Resultados TABLE
(
    Cenario varchar(80) NOT NULL,
    GiniEsperado float NULL,
    GiniObtido float NULL,
    EntropiaEsperada float NULL,
    EntropiaObtida float NULL
);

INSERT INTO @Resultados
VALUES ('Dados ficticios: 8 / 2', 0.32, dbo.fn_gini(@Frequencias),
        0.7219280948873623, dbo.fn_entropia(@Frequencias));

DELETE FROM @Frequencias;
INSERT INTO @Frequencias (Qtd) VALUES (5), (5);
INSERT INTO @Resultados
VALUES ('Duas classes equilibradas', 0.5, dbo.fn_gini(@Frequencias),
        1.0, dbo.fn_entropia(@Frequencias));

DELETE FROM @Frequencias;
INSERT INTO @Frequencias (Qtd) VALUES (10), (0);
INSERT INTO @Resultados
VALUES ('Classe pura e frequencia zero', 0.0, dbo.fn_gini(@Frequencias),
        0.0, dbo.fn_entropia(@Frequencias));

DELETE FROM @Frequencias;
INSERT INTO @Frequencias (Qtd) VALUES (4), (4), (4);
INSERT INTO @Resultados
VALUES ('Tres classes equilibradas', 0.6666666666666667, dbo.fn_gini(@Frequencias),
        1.584962500721156, dbo.fn_entropia(@Frequencias));

DELETE FROM @Frequencias;
INSERT INTO @Resultados
VALUES ('Tabela vazia', NULL, dbo.fn_gini(@Frequencias),
        NULL, dbo.fn_entropia(@Frequencias));

INSERT INTO @Frequencias (Qtd) VALUES (0), (0);
INSERT INTO @Resultados
VALUES ('Todas as frequencias zeradas', NULL, dbo.fn_gini(@Frequencias),
        NULL, dbo.fn_entropia(@Frequencias));

DELETE FROM @Frequencias;
INSERT INTO @Frequencias (Qtd)
VALUES (9223372036854775807), (9223372036854775807);
INSERT INTO @Resultados
VALUES ('Total maior que o limite de bigint', 0.5, dbo.fn_gini(@Frequencias),
        1.0, dbo.fn_entropia(@Frequencias));

SELECT * FROM @Resultados ORDER BY Cenario;

-- Verifica NULL explicitamente para que resultados ausentes nao passem no teste.
IF EXISTS
(
    SELECT 1
    FROM @Resultados
    WHERE (GiniEsperado IS NULL AND GiniObtido IS NOT NULL)
       OR (GiniEsperado IS NOT NULL
           AND (GiniObtido IS NULL OR ABS(GiniObtido - GiniEsperado) > 1e-12))
       OR (EntropiaEsperada IS NULL AND EntropiaObtida IS NOT NULL)
       OR (EntropiaEsperada IS NOT NULL
           AND (EntropiaObtida IS NULL OR ABS(EntropiaObtida - EntropiaEsperada) > 1e-12))
)
BEGIN
    THROW 51000, 'FAIL: resultado de Gini ou entropia diferente do esperado.', 1;
END;

PRINT 'PASS: 7 cenarios de Gini e entropia validados.';
GO
