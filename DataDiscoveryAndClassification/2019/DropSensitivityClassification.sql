CREATE PROCEDURE [DC].[DropSensitivityClassification]
AS
BEGIN
SET NOCOUNT ON;
DECLARE @version AS VARCHAR(128)
SET @version = 
  CASE 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '8%' THEN 'SQL2000'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '9%' THEN 'SQL2005'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.0%' THEN 'SQL2008'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.5%' THEN 'SQL2008 R2'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '11%' THEN 'SQL2012'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '12%' THEN 'SQL2014'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '13%' THEN 'SQL2016'     
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '14%' THEN 'SQL2017' 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '15%' THEN 'SQL2019' 
     ELSE 'unknown'
  END 
IF ( @version != 'SQL2019')
BEGIN
PRINT 'Only for SQL2019';
RETURN 0
END

DECLARE @id AS INT;
DECLARE @maxId AS INT;
DECLARE @cSchema AS SYSNAME;
DECLARE @cTable AS SYSNAME;
DECLARE @cColumn AS SYSNAME;
DECLARE @sqlString AS NVARCHAR(MAX)

SET @id = 1;

IF OBJECT_ID('tempdb..#TempResult') IS NOT NULL
    DROP TABLE #TempResult;
SELECT GCC.*,
    ROW_NUMBER() OVER(ORDER BY SchemaName,
                                TABLENAME,
                                COLUMNNAME) RN
INTO #TempResult
FROM   [DC].[GetClassifiedColumns] GCC



	         SET @maxid =
(
    SELECT MAX(RN)
    FROM   #TempResult
);
         WHILE @maxId >= @Id
             BEGIN
                 SET @cschema =
(
    SELECT TOP 1 SchemaName
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

                SET @ID = @ID + 1;
				SET @sqlString = 'DROP SENSITIVITY CLASSIFICATION FROM '
				SET @sqlString =  @sqlstring + @cSchema + '.' + @cTable + '.' + @cColumn
				EXECUTE sp_executesql @sqlString;
             END;

     END; 


RETURN 0
