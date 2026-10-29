-- Moves classifications kept in extended properties (SSMS before SQL Server 2019, and version 1
-- of this project) into sys.sensitivity_classifications. A column that is classified there
-- already keeps its classification. The rank comes from DC.SensitiveName when the label is in it.
-- With @DropLegacy = 1 the four extended properties are dropped afterwards, from every column.
CREATE PROCEDURE [DC].[MigrateLegacyClassification]
    @DropLegacy BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @statement AS NVARCHAR (MAX);
    DECLARE @migrated AS INT = 0;
    DECLARE @dropped AS INT = 0;
    DECLARE @schemaName AS SYSNAME;
    DECLARE @tableName AS SYSNAME;
    DECLARE @columnName AS SYSNAME;
    DECLARE @propertyName AS SYSNAME;

    DECLARE Legacy CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
        SELECT DC.AddClassificationStatement(
            L.SchemaName,
            L.TableName,
            L.ColumnName,
            L.SensitivityLabel,
            L.SensitivityLabelId,
            L.InformationType,
            L.InformationTypeId,
            SN.LabelRank)
        FROM DC.GetLegacyClassifiedColumns AS L
            LEFT JOIN DC.SensitiveName AS SN
                ON SN.LabelId = TRY_CONVERT(UNIQUEIDENTIFIER, L.SensitivityLabelId)
                OR (L.SensitivityLabelId IS NULL AND SN.LabelName = L.SensitivityLabel)
        WHERE L.IsClassified = 0
            AND L.IsComputed = 0
            AND L.IsHistoryTable = 0;

    DECLARE Properties CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
        SELECT SCHEMA_NAME(O.schema_id), O.name, C.name, EP.name
        FROM sys.extended_properties AS EP
            INNER JOIN sys.objects AS O
                ON O.object_id = EP.major_id
            INNER JOIN sys.columns AS C
                ON C.object_id = EP.major_id
                AND C.column_id = EP.minor_id
        WHERE EP.class = 1
            AND O.type = 'U'
            AND EP.name IN (N'sys_information_type_name', N'sys_information_type_id', N'sys_sensitivity_label_name', N'sys_sensitivity_label_id');

    BEGIN TRANSACTION;

    OPEN Legacy;
    FETCH NEXT FROM Legacy INTO @statement;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @statement IS NOT NULL
        BEGIN
            EXECUTE sys.sp_executesql @statement;
            SET @migrated += 1;
        END;
        FETCH NEXT FROM Legacy INTO @statement;
    END;
    CLOSE Legacy;
    DEALLOCATE Legacy;

    IF @DropLegacy = 1
    BEGIN
        OPEN Properties;
        FETCH NEXT FROM Properties INTO @schemaName, @tableName, @columnName, @propertyName;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXECUTE sys.sp_dropextendedproperty
                @name = @propertyName,
                @level0type = N'SCHEMA', @level0name = @schemaName,
                @level1type = N'TABLE', @level1name = @tableName,
                @level2type = N'COLUMN', @level2name = @columnName;
            SET @dropped += 1;
            FETCH NEXT FROM Properties INTO @schemaName, @tableName, @columnName, @propertyName;
        END;
        CLOSE Properties;
    END;
    DEALLOCATE Properties;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'Migrated ', @migrated, N' column(s); dropped ', @dropped, N' extended propert', IIF(@dropped = 1, N'y', N'ies'), N'.');
END;
