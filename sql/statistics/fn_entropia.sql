-- Entropia de Shannon em bits: -SUM(p * LOG(p) / LOG(2.0)).
CREATE OR ALTER FUNCTION dbo.fn_entropia
(
    @Frequencias dbo.FrequenciasClasse READONLY
)
RETURNS float
AS
BEGIN
    DECLARE @Total float;
    DECLARE @Entropia float;

    SELECT @Total = SUM(CONVERT(float, Qtd))
    FROM @Frequencias;

    IF @Total IS NULL OR @Total = 0
        RETURN NULL;

    SELECT @Entropia = -SUM(Prob * (LOG(NULLIF(Prob, 0.0)) / LOG(2.0)))
    FROM
    (
        SELECT CONVERT(float, Qtd) / @Total AS Prob
        FROM @Frequencias
        WHERE Qtd > 0
    ) AS Distribuicao;

    -- Classes com frequencia zero contribuem com zero; NULLIF protege LOG(0).
    RETURN @Entropia;
END;
GO
