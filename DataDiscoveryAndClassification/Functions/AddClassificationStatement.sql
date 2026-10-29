-- Builds one ADD SENSITIVITY CLASSIFICATION statement. Names are quoted and values escaped,
-- so any schema, table, column or label name is safe. NULL options are left out, and a rank
-- outside NONE, LOW, MEDIUM, HIGH and CRITICAL is ignored. Returns NULL when there is nothing to add.
CREATE FUNCTION [DC].[AddClassificationStatement]
(
    @SchemaName        SYSNAME,
    @TableName         SYSNAME,
    @ColumnName        SYSNAME,
    @Label             NVARCHAR (128),
    @LabelId           NVARCHAR (128),
    @InformationType   NVARCHAR (128),
    @InformationTypeId NVARCHAR (128),
    @Rank              NVARCHAR (10)
)
RETURNS NVARCHAR (MAX)
AS
BEGIN
    DECLARE @options AS NVARCHAR (MAX) = CONCAT_WS(
        N', ',
        N'LABEL = N''' + REPLACE(@Label, N'''', N'''''') + N'''',
        N'LABEL_ID = N''' + REPLACE(@LabelId, N'''', N'''''') + N'''',
        N'INFORMATION_TYPE = N''' + REPLACE(@InformationType, N'''', N'''''') + N'''',
        N'INFORMATION_TYPE_ID = N''' + REPLACE(@InformationTypeId, N'''', N'''''') + N'''',
        CASE WHEN UPPER(@Rank) IN (N'NONE', N'LOW', N'MEDIUM', N'HIGH', N'CRITICAL') THEN N'RANK = ' + UPPER(@Rank) END
    );

    IF @options = N''
        RETURN NULL;

    RETURN N'ADD SENSITIVITY CLASSIFICATION TO '
        + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N'.' + QUOTENAME(@ColumnName)
        + N' WITH (' + @options + N');';
END;
