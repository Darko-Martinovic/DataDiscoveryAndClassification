-- Every classified column, as SQL Server stores it in sys.sensitivity_classifications.
-- Reading it needs the VIEW ANY SENSITIVITY CLASSIFICATION permission. The casts are for
-- SQL Server 2019, where the catalog view returns these columns as sql_variant.
CREATE VIEW [DC].[GetClassifiedColumns]
AS
SELECT
    SCHEMA_NAME(O.schema_id)                             AS SchemaName,
    O.name                                               AS TableName,
    C.name                                               AS ColumnName,
    CAST(SC.information_type AS NVARCHAR (128))          AS InformationType,
    CAST(SC.information_type_id AS NVARCHAR (128))       AS InformationTypeId,
    CAST(SC.label AS NVARCHAR (128))                     AS SensitivityLabel,
    CAST(SC.label_id AS NVARCHAR (128))                  AS SensitivityLabelId,
    CAST(SC.rank_desc AS NVARCHAR (10))                  AS SensitivityRank,
    CAST(CASE WHEN T.temporal_type = 1 THEN 1 ELSE 0 END AS BIT) AS IsHistoryTable
FROM sys.sensitivity_classifications AS SC
    INNER JOIN sys.objects AS O
        ON O.object_id = SC.major_id
    INNER JOIN sys.columns AS C
        ON C.object_id = SC.major_id
        AND C.column_id = SC.minor_id
    LEFT JOIN sys.tables AS T
        ON T.object_id = O.object_id
WHERE SC.class = 1;
