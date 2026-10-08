-- Impureza de Gini: 1 - SUM(p * p), com p = Qtd / total.
CREATE OR ALTER FUNCTION dbo.fn_gini
(
    @Frequencias dbo.FrequenciasClasse READONLY
)
RETURNS float
AS
BEGIN
    DECLARE @Total float;
    DECLARE @Gini float;

    -- Converter antes de somar evita overflow de bigint no total.
    SELECT @Total = SUM(CONVERT(float, Qtd))
    FROM @Frequencias;

    -- Sem observacoes, a distribuicao de probabilidades nao esta definida.
    IF @Total IS NULL OR @Total = 0
        RETURN NULL;

    SELECT @Gini = 1.0 - SUM(Prob * Prob)
    FROM
    (
        SELECT CONVERT(float, Qtd) / @Total AS Prob
        FROM @Frequencias
        WHERE Qtd > 0
    ) AS Distribuicao;

    RETURN @Gini;
END;
GO
