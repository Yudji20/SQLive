-- Uma linha por classe, com a quantidade de observacoes dessa classe.
-- Os rotulos nao sao necessarios para calcular Gini ou entropia.
IF TYPE_ID(N'dbo.FrequenciasClasse') IS NULL
BEGIN
    EXEC(N'CREATE TYPE dbo.FrequenciasClasse AS TABLE
    (
        Qtd bigint NOT NULL CHECK (Qtd >= 0)
    );');
END;
GO
