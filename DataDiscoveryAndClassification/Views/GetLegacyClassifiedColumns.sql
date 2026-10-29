-- Columns classified the way SSMS did it before SQL Server 2019, and version 1 of this project:
-- in the extended properties sys_information_type_name, sys_information_type_id,
-- sys_sensitivity_label_name and sys_sensitivity_label_id.
CREATE VIEW [DC].[GetLegacyClassifiedColumns]
AS
SELECT
    SCHEMA_NAME(O.schema_id)          AS SchemaName,
    O.name                            AS TableName,
    C.name                            AS ColumnName,
    CAST(ITN.value AS NVARCHAR (128)) AS InformationType,
    CAST(ITI.value AS NVARCHAR (128)) AS InformationTypeId,
    CAST(SLN.value AS NVARCHAR (128)) AS SensitivityLabel,
    CAST(SLI.value AS NVARCHAR (128)) AS SensitivityLabelId,
    C.is_computed                     AS IsComputed,
    CAST(CASE WHEN T.temporal_type = 1 THEN 1 ELSE 0 END AS BIT) AS IsHistoryTable,
    CAST(CASE WHEN EXISTS
        (
            SELECT 1
            FROM sys.sensitivity_classifications AS SC
            WHERE SC.class = 1
                AND SC.major_id = EP.major_id
                AND SC.minor_id = EP.minor_id
        ) THEN 1 ELSE 0 END AS BIT) AS IsClassified
FROM
(
    SELECT DISTINCT major_id, minor_id
    FROM sys.extended_properties
    WHERE class = 1
        AND minor_id > 0
        AND name IN (N'sys_information_type_name', N'sys_information_type_id', N'sys_sensitivity_label_name', N'sys_sensitivity_label_id')
) AS EP
    INNER JOIN sys.objects AS O
        ON O.object_id = EP.major_id
    INNER JOIN sys.columns AS C
        ON C.object_id = EP.major_id
        AND C.column_id = EP.minor_id
    LEFT JOIN sys.tables AS T
        ON T.object_id = O.object_id
    LEFT JOIN sys.extended_properties AS ITN
        ON ITN.class = 1 AND ITN.major_id = EP.major_id AND ITN.minor_id = EP.minor_id AND ITN.name = N'sys_information_type_name'
    LEFT JOIN sys.extended_properties AS ITI
        ON ITI.class = 1 AND ITI.major_id = EP.major_id AND ITI.minor_id = EP.minor_id AND ITI.name = N'sys_information_type_id'
    LEFT JOIN sys.extended_properties AS SLN
        ON SLN.class = 1 AND SLN.major_id = EP.major_id AND SLN.minor_id = EP.minor_id AND SLN.name = N'sys_sensitivity_label_name'
    LEFT JOIN sys.extended_properties AS SLI
        ON SLI.class = 1 AND SLI.major_id = EP.major_id AND SLI.minor_id = EP.minor_id AND SLI.name = N'sys_sensitivity_label_id'
WHERE O.type = 'U';
