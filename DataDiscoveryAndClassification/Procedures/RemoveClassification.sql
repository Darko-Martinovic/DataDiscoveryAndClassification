CREATE PROCEDURE [DC].[RemoveClassification]
AS
     BEGIN
         SET NOCOUNT ON;
         DECLARE @id AS INT;
         DECLARE @maxId AS INT;
         DECLARE @cSchema AS SYSNAME;
         DECLARE @cTable AS SYSNAME;
         DECLARE @cColumn AS SYSNAME;
         IF OBJECT_ID('tempdb..#TempResult') IS NOT NULL
             DROP TABLE #TempResult;
		 SET @id = 1;
         SELECT dcc.*,
                ROW_NUMBER() OVER(ORDER BY SchemaName,
                                           TableName,
                                           ColumnName) RN
         INTO #tempresult
         FROM   DC.GetClassifiedColumns dcc;
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
                 EXEC sp_dropextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_information_type_name';
                 EXEC sp_dropextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_information_type_id';
                 EXEC sp_dropextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_sensitivity_label_name';
                 EXEC sp_dropextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_sensitivity_label_id';
                 SET @ID = @ID + 1;
             END;
     END;
