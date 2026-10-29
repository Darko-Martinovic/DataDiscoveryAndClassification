-- Every column of a user table whose name matches a keyword, with the keyword's information type.
-- Left out: the DC schema, bit columns, computed columns and history tables (SQL Server refuses to
-- classify those two; a history table takes the classification of its current table), and numeric
-- columns for keywords that can't be numeric.
CREATE VIEW [DC].[GetMatchingColumns]
AS
SELECT
    S.name        AS SchemaName,
    T.name        AS TableName,
    C.name        AS ColumnName,
    T.object_id   AS TableObjectId,
    C.column_id   AS ColumnId,
    K.InfoTypeId  AS InfoTypeId,
    K.KeywordName AS KeywordName
FROM sys.tables AS T
    INNER JOIN sys.schemas AS S
        ON S.schema_id = T.schema_id
    INNER JOIN sys.columns AS C
        ON C.object_id = T.object_id
    INNER JOIN DC.KeyWords AS K
        ON LOWER(C.name) COLLATE Latin1_General_100_BIN2 LIKE LOWER(K.KeywordName) COLLATE Latin1_General_100_BIN2
WHERE T.is_ms_shipped = 0
    AND T.is_external = 0
    AND T.temporal_type <> 1
    AND C.is_computed = 0
    AND S.name <> N'DC'
    AND TYPE_NAME(C.system_type_id) <> N'bit'
    AND (K.CanBeNumeric = 1
        OR TYPE_NAME(C.system_type_id) NOT IN (N'bigint', N'decimal', N'float', N'int', N'money', N'numeric', N'real', N'smallint', N'smallmoney', N'tinyint'));
