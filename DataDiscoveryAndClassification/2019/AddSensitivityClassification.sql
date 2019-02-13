CREATE PROCEDURE [DC].[AddSensitivityClassification]
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
DECLARE @cInformationTypeName AS VARCHAR(50);
DECLARE @cInformationTypeId AS VARCHAR(50);
DECLARE @cSensitivityLabel AS VARCHAR(50);
DECLARE @cSensitivitLableId AS VARCHAR(50);
DECLARE @sqlString AS NVARCHAR(MAX)

SET @id = 1;

IF OBJECT_ID('tempdb..#TempResult') IS NOT NULL
    DROP TABLE #TempResult;
SELECT GCC.*,
    ROW_NUMBER() OVER(ORDER BY SCHEMANAME,
                                TABLENAME,
                                COLUMNNAME) RN,
    CAST(IT.InfoTypeId AS VARCHAR(50)) InformationTypeId,
	CAST(SN.LabelId AS VARCHAR(50)) SensitivityLabelId
INTO #TempResult
FROM   [DC].[GetClassifiedColumns] GCC
INNER JOIN DC.SensitiveName SN 
	ON GCC.SensitivityLabel = SN.LabelName
INNER JOIN DC.InformationType IT 
	ON GCC.InformationType = IT.InfoTypeName



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
                 SET @cInformationTypeName =
(
    SELECT TOP 1 InformationType
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
    SELECT TOP 1 SensitivityLabel
    FROM         #TempResult
    WHERE        rn = @id
);
                 SET @cSensitivitLableId =
(
    SELECT TOP 1 SensitivityLabelId
    FROM         #TempResult
    WHERE        rn = @id
);


                 SET @ID = @ID + 1;
	SET @sqlString = 'ADD SENSITIVITY CLASSIFICATION TO '
	SET @sqlString =  @sqlstring + @cSchema + '.' + @cTable + '.' + @cColumn
	SET @sqlString =  @sqlString + ' WITH ( LABEL_ID='''
	SET @sqlString =  @sqlString + CAST(@cSensitivitLableId AS VARCHAR(50)) + ''''
    SET @sqlString =  @sqlString + '  ,LABEL='''
	SET @sqlString =  @sqlString + @cSensitivityLabel + ''''
    SET @sqlString =  @sqlString + '  ,INFORMATION_TYPE_ID='''
	SET @sqlString =  @sqlString + @cInformationTypeId + ''''
    SET @sqlString =  @sqlString + '  ,INFORMATION_TYPE='''
	SET @sqlString =  @sqlString + @cInformationTypeName + ''''
	SET @sqlString =  @sqlString + ')'
	EXECUTE sp_executesql @sqlString;
             END;

     END; 


RETURN 0
