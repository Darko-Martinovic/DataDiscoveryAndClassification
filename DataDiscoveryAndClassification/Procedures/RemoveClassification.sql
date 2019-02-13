CREATE PROCEDURE [DC].[RemoveClassification]
AS
     BEGIN
         SET NOCOUNT ON;
         DECLARE @id AS INT= 1;
         DECLARE @maxId AS INT;
         DECLARE @cSchema AS SYSNAME;
         DECLARE @cTable AS SYSNAME;
         DECLARE @cColumn AS SYSNAME;
         DECLARE @cInformationTypeName AS VARCHAR(50);
         DECLARE @cInformationTypeId AS VARCHAR(50);
         DECLARE @cSensitivityLabel AS VARCHAR(50);
         DECLARE @cSensitivitLableId AS VARCHAR(50);
         IF OBJECT_ID('tempdb..#TempResult') IS NOT NULL
             DROP TABLE #TempResult;
         SELECT dcc.*,
                ROW_NUMBER() OVER(ORDER BY SchemaName,
                                           TableName,
                                           ColumnName) RN,
                sn.LabelId,
                it.InfoTypeId
         INTO #tempresult
         FROM   DC.GetClassifiedColumns dcc
                INNER JOIN dc.InformationType it ON dcc.InformationType =
                it.InfoTypeName
                INNER JOIN dc.SensitiveName sn ON dcc.SensitivityLabel =
                sn.LabelName;
         SET @maxid =
(
    SELECT MAX(RN)
    FROM   #TempResult
);
         WHILE @maxId >= @Id
             BEGIN
                 SET @cschema =
(
    SELECT TOP 1 SCHEMAname
    FROM         #TempResult
    WHERE        rn = @id
);
                 SET @cTable =
(
    SELECT TOP 1 TableName
    FROM         #TempResult
    WHERE        rn = @id
);
                 SET @cColumn =
(
    SELECT TOP 1 ColumnName
    FROM         #TempResult
    WHERE        rn = @id
);
                 SET @cInformationTypeName =
(
    SELECT TOP 1 InformationTypeName
    FROM         #TempResult
    WHERE        rn = @id
);
                 SET @cInformationTypeId =
(
    SELECT TOP 1 InformationTypeId
    FROM         #TempResult
    WHERE        rn = @id
);
                 SET @cSensitivityLabel =
(
    SELECT TOP 1 SensitivityLabelName
    FROM         #TempResult
    WHERE        rn = @id
);
                 SET @cSensitivitLableId =
(
    SELECT TOP 1 SensitivityLabelId
    FROM         #TempResult
    WHERE        rn = @id
);
                 EXEC sp_dropextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_information_type_name',
                      @value = @cInformationTypeName;
                 EXEC sp_dropextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_information_type_id',
                      @value = @cInformationTypeId;
                 EXEC sp_dropextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_sensitivity_label_name',
                      @value = @cSensitivityLabel;
                 EXEC sp_dropextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_sensitivity_label_id',
                      @value = @cSensitivitLableId;
                 SET @ID = @ID + 1;
             END;
     END;
