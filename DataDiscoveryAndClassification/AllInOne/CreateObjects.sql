PRINT N'Creating [DC]...';


GO
CREATE SCHEMA [DC]
    AUTHORIZATION [dbo];


GO
PRINT N'Creating [DC].[KeyWords]...';


GO
CREATE TABLE [DC].[KeyWords] (
    [KeywordName]  VARCHAR (50)     COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
    [CanBeNumeric] BIT              NOT NULL,
    [InfoTypeId]   UNIQUEIDENTIFIER NOT NULL,
    [ShouldLike]   BIT              NOT NULL,
    CONSTRAINT [PK_KeyWords] PRIMARY KEY CLUSTERED ([KeywordName] ASC) ON [PRIMARY]
) ON [PRIMARY];


GO
PRINT N'Creating [DC].[InformationType]...';


GO
CREATE TABLE [DC].[InformationType] (
    [InfoTypeId]         UNIQUEIDENTIFIER NOT NULL,
    [InfoTypeName]       VARCHAR (30)     NOT NULL,
    [InfoTypeOrder]      INT              NOT NULL,
    [RecommendedLabelId] UNIQUEIDENTIFIER NULL,
    CONSTRAINT [PK__Informat__E94AB524B904E7BD] PRIMARY KEY CLUSTERED ([InfoTypeId] ASC) ON [PRIMARY]
) ON [PRIMARY];


GO
PRINT N'Creating [DC].[InformationType].[IX_InformationType_Name]...';


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_InformationType_Name]
    ON [DC].[InformationType]([InfoTypeName] ASC);


GO
PRINT N'Creating [DC].[InformationType].[IX_InformationType_Order]...';


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_InformationType_Order]
    ON [DC].[InformationType]([InfoTypeOrder] ASC);


GO
PRINT N'Creating [DC].[SensitiveName]...';


GO
CREATE TABLE [DC].[SensitiveName] (
    [LabelId]    UNIQUEIDENTIFIER NOT NULL,
    [LabelName]  VARCHAR (30)     NOT NULL,
    [LabelOrder] INT              NOT NULL,
    CONSTRAINT [PK__Sensitiv__397E2BC37BCB31E5] PRIMARY KEY CLUSTERED ([LabelId] ASC) ON [PRIMARY]
) ON [PRIMARY];


GO
PRINT N'Creating [DC].[SensitiveName].[IX_SensitiveName_LabelName]...';


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_SensitiveName_LabelName]
    ON [DC].[SensitiveName]([LabelName] ASC);


GO
PRINT N'Creating [DC].[SensitiveName].[IX_SensitiveName_LabelOrder]...';


GO
CREATE NONCLUSTERED INDEX [IX_SensitiveName_LabelOrder]
    ON [DC].[SensitiveName]([LabelOrder] ASC);


GO
PRINT N'Creating [DC].[FK_KeyWords_InformationType]...';


GO
ALTER TABLE [DC].[KeyWords] WITH NOCHECK
    ADD CONSTRAINT [FK_KeyWords_InformationType] FOREIGN KEY ([InfoTypeId]) REFERENCES [DC].[InformationType] ([InfoTypeId]);


GO
PRINT N'Creating [DC].[FK_InformationType_SensitiveName]...';


GO
ALTER TABLE [DC].[InformationType] WITH NOCHECK
    ADD CONSTRAINT [FK_InformationType_SensitiveName] FOREIGN KEY ([RecommendedLabelId]) REFERENCES [DC].[SensitiveName] ([LabelId]);


GO
PRINT N'Creating [DC].[GetMatchingColumns]...';


GO
CREATE VIEW DC.GetMatchingColumns
as
SELECT DISTINCT
	name
   ,CanBeNumeric
   ,InfoTypeId
FROM (SELECT DISTINCT
		LOWER(name) AS name
	FROM sys.columns) AS Columns
INNER JOIN DC.KeyWords
	ON (ShouldLike = 0
			AND name COLLATE Latin1_GENERAL_BIN = KeywordName COLLATE Latin1_GENERAL_BIN)
		OR (ShouldLike = 1
			AND name COLLATE Latin1_GENERAL_BIN LIKE KeywordName COLLATE Latin1_GENERAL_BIN)
GO
PRINT N'Creating [DC].[GetClassifiedColumns]...';


GO
CREATE VIEW DC.GetClassifiedColumns
AS 

SELECT
    schema_name(O.schema_id) AS SchemaName,
    O.name AS TableName,
    C.name AS ColumnName,
    CAST(information_type AS VARCHAR(50)) InformationType,
    CAST(sensitivity_label AS VARCHAR(50)) SensitivityLabel,
	c.is_computed IsComputed
FROM
    (
        SELECT
            IT.major_id,
            IT.minor_id,
            IT.information_type,
            L.sensitivity_label 
        FROM
        (
            SELECT
                major_id,
                minor_id,
                value AS information_type 
            FROM sys.extended_properties 
            WHERE name = 'sys_information_type_name'
        ) IT 
        FULL OUTER JOIN
        (
            SELECT
                major_id,
                minor_id,
                value AS sensitivity_label 
            FROM sys.extended_properties 
            WHERE name = 'sys_sensitivity_label_name'
        ) L 
        ON IT.major_id = L.major_id AND IT.minor_id = L.minor_id
    ) EP
    JOIN sys.objects O
    ON  EP.major_id = O.object_id 
    JOIN sys.columns C 
    ON  EP.major_id = C.object_id AND EP.minor_id = C.column_id
GO
PRINT N'Creating [DC].[GetIntermediateResults]...';


GO
CREATE VIEW [DC].[GetIntermediateResults]
AS

WITH IntermediateResults as
(
SELECT DISTINCT
		S.name AS SchemaName
	   ,T.name AS TableName
	   ,C.name AS ColumnName
	   ,INFOTYPES.InfoTypeId AS InfoTypeId
	   ,INFOTYPES.InfoTypeName AS InfoTypeName
	   ,INFOTYPES.InfoTypeOrder AS InfoTypeOrder
	   ,INFOTYPES.RecommendedLabelId AS LabelId
	   ,SENSITIVITYLABLES.LabelName AS LabelName
	   ,SENSITIVITYLABLES.LabelOrder AS LabelOrder
	FROM sys.schemas S
	INNER JOIN sys.tables T
		ON S.schema_id = T.schema_id
		--AND T.is_memory_optimized = 0
	INNER JOIN sys.columns C
		ON T.object_id = C.object_id
	INNER JOIN sys.types TYPE
		ON C.system_type_id = TYPE.system_type_id
		AND TYPE.name != 'bit'
	INNER JOIN DC.GetMatchingColumns MC
		ON LOWER(C.name) = MC.name
		AND -- No need to convert MC.name to lower case, as it was already done.
		NOT (MC.CanBeNumeric = 0
		AND TYPE.name IN ('bigint', 'bit', 'decimal', 'float', 'int', 'money', 'numeric', 'smallint', 'smallmoney', 'tinyint'))
	INNER JOIN DC.InformationType INFOTYPES
		ON MC.InfoTypeId = INFOTYPES.InfoTypeId
	LEFT JOIN DC.SensitiveName SENSITIVITYLABLES
		ON INFOTYPES.RecommendedLabelId = SENSITIVITYLABLES.LabelId
),
Result As
(
SELECT DISTINCT
    IR.SchemaName AS SchemaName,
    IR.TableName AS TableName,
    IR.ColumnName AS ColumnName,
    IR.InfoTypeId AS InformationTypeId,
    IR.InfoTypeName AS InformationTypeName,
    IR.LabelId AS SensitivityLabelId,
    IR.LabelName AS SensitivityLabelName
FROM IntermediateResults IR
    INNER JOIN (SELECT SchemaName, TableName, ColumnName, MIN(InfoTypeOrder) AS MinOrder
                FROM IntermediateResults
                GROUP BY SchemaName, TableName, ColumnName) MR
    ON IR.SchemaName = MR.SchemaName AND IR.TableName = MR.TableName
    AND IR.ColumnName = MR.ColumnName AND IR.InfoTypeOrder = MR.MinOrder
WHERE IR.SchemaName <> 'DC'
)
SELECT * FROM Result IR
WHERE NOT EXISTS
( SELECT * FROM DC.GetClassifiedColumns GCC 
   WHERE IR.SchemaName = GCC.SchemaName AND IR.TableName = GCC.TableName AND IR.ColumnName = GCC.ColumnName
   )
GO
PRINT N'Creating [DC].[AcceptSuggestions]...';


GO
CREATE PROCEDURE DC.AcceptSuggestions
AS
     BEGIN
         SET NOCOUNT ON;
         DECLARE @id AS INT;
         DECLARE @maxId AS INT;
         DECLARE @cSchema AS SYSNAME;
         DECLARE @cTable AS SYSNAME;
         DECLARE @cColumn AS SYSNAME;
         DECLARE @cInformationTypeName AS VARCHAR(50);
         DECLARE @cInformationTypeId AS VARCHAR(50);
         DECLARE @cSensitivityLabel AS VARCHAR(50);
         DECLARE @cSensitivitLableId AS VARCHAR(50);
		 SET @id = 1;
         IF OBJECT_ID('tempdb..#TempResult') IS NOT NULL
             DROP TABLE #TempResult;
         SELECT *,
                ROW_NUMBER() OVER(ORDER BY SCHEMANAME,
                                           TABLENAME,
                                           COLUMNNAME) RN
         INTO #TempResult
         FROM   DC.GetIntermediateResults;
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
                 EXEC sp_addextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_information_type_name',
                      @value = @cInformationTypeName;
                 EXEC sp_addextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_information_type_id',
                      @value = @cInformationTypeId;
                 EXEC sp_addextendedproperty
                      @level0type = 'schema',
                      @level0name = @cSchema,
                      @level1type = 'table',
                      @level1name = @cTable,
                      @level2type = 'column',
                      @level2name = @cColumn,
                      @name = 'sys_sensitivity_label_name',
                      @value = @cSensitivityLabel;
                 EXEC sp_addextendedproperty
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
GO
PRINT N'Creating [DC].[RemoveClassification]...';


GO
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
                      @name = N'sys_information_type_name',
                      @level0type = N'schema',
                      @level0name = @cSchema,
                      @level1type = N'table',
                      @level1name = @cTable,
                      @level2type = N'column',
                      @level2name = @cColumn;
                 EXEC sp_dropextendedproperty
                      @name = N'sys_information_type_id',
                      @level0type = N'schema',
                      @level0name = @cSchema,
                      @level1type = N'table',
                      @level1name = @cTable,
                      @level2type = N'column',
                      @level2name = @cColumn;
                 EXEC sp_dropextendedproperty
                      @name = N'sys_sensitivity_label_name',
                      @level0type = N'schema',
                      @level0name = @cSchema,
                      @level1type = N'table',
                      @level1name = @cTable,
                      @level2type = N'column',
                      @level2name = @cColumn;
                 EXEC sp_dropextendedproperty
                      @name = N'sys_sensitivity_label_id',
                      @level0type = N'schema',
                      @level0name = @cSchema,
                      @level1type = N'table',
                      @level1name = @cTable,
                      @level2type = N'column',
                      @level2name = @cColumn;
                 SET @ID = @ID + 1;
             END;
     END;
GO
PRINT N'Creating [DC].[AddSensitivityClassification]...';


GO
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
    ROW_NUMBER() OVER(ORDER BY SchemaName,
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
WHERE GCC.IsComputed = 0


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
GO
PRINT N'Creating [DC].[DropSensitivityClassification]...';


GO
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
WHERE IsComputed = 0



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
GO
/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/

--== Fill tables 
IF (SELECT COUNT(*) FROM [DC].[SensitiveName]) = 0
BEGIN 
	INSERT [DC].[SensitiveName] ([LabelId], [LabelName], [LabelOrder]) VALUES (N'1866ca45-1973-4c28-9d12-04d407f147ad', N'Public', 100);
	INSERT [DC].[SensitiveName] ([LabelId], [LabelName], [LabelOrder]) VALUES (N'3302ae7f-b8ac-46bc-97f8-378828781efd', N'Highly Confidential - GDPR', 600);
	INSERT [DC].[SensitiveName] ([LabelId], [LabelName], [LabelOrder]) VALUES (N'b82ce05b-60a9-4cf3-8a8a-d6a0bb76e903', N'Highly Confidential', 500);
	INSERT [DC].[SensitiveName] ([LabelId], [LabelName], [LabelOrder]) VALUES (N'331f0b13-76b5-2f1b-a77b-def5a73c73c2', N'Confidential', 300);
	INSERT [DC].[SensitiveName] ([LabelId], [LabelName], [LabelOrder]) VALUES (N'684a0db2-d514-49d8-8c0c-df84a7b083eb', N'General', 200);
	INSERT [DC].[SensitiveName] ([LabelId], [LabelName], [LabelOrder]) VALUES (N'989adc05-3f3f-0588-a635-f475b994915b', N'Confidential - GDPR', 400);

END 


IF (SELECT COUNT(*) FROM [DC].[InformationType]) = 0
BEGIN 
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'57845286-7598-22f5-9659-15b24aeb125e', N'Name', 400, N'989adc05-3f3f-0588-a635-f475b994915b')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'b40ad280-0f6a-6ca8-11ba-2f1a08651fcf', N'Networking', 100, N'331f0b13-76b5-2f1b-a77b-def5a73c73c2')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'd936ec2c-04a4-9cf7-44c2-378a96456c61', N'SSN', 600, N'989adc05-3f3f-0588-a635-f475b994915b')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'c64aba7b-3a3e-95b6-535d-3bc535da5a59', N'Credentials', 300, N'331f0b13-76b5-2f1b-a77b-def5a73c73c2')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'3de7cc52-710d-4e96-7e20-4d5188d2590c', N'Date Of Birth', 1100, N'989adc05-3f3f-0588-a635-f475b994915b')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', N'National ID', 500, N'989adc05-3f3f-0588-a635-f475b994915b')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'9c5b4809-0ccc-0637-6547-91a6f8bb609d', N'Other', 1200, N'331f0b13-76b5-2f1b-a77b-def5a73c73c2')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', N'Credit Card', 700, N'331f0b13-76b5-2f1b-a77b-def5a73c73c2')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'8a462631-4130-0a31-9a52-c6a9ca125f92', N'Banking', 800, N'331f0b13-76b5-2f1b-a77b-def5a73c73c2')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'6e2c5b18-97cf-3073-27ab-f12f87493da7', N'Health', 1000, N'989adc05-3f3f-0588-a635-f475b994915b')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'5c503e21-22c6-81fa-620b-f369b8ec38d1', N'Contact Info', 200, N'331f0b13-76b5-2f1b-a77b-def5a73c73c2')
	INSERT [DC].[InformationType] ([InfoTypeId], [InfoTypeName], [InfoTypeOrder], [RecommendedLabelId]) VALUES (N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', N'Financial', 900, N'331f0b13-76b5-2f1b-a77b-def5a73c73c2')
END

IF (SELECT COUNT(*) FROM [DC].[KeyWords]) = 0
BEGIN
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%[^h]ip%address%', 0, N'b40ad280-0f6a-6ca8-11ba-2f1a08651fcf', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%aba%routing%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%ablauf%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%account%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%acct%nbr%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%acct%no%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%acct%num%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%addr%', 0, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%american%express%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%americanexpress%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%americano%espresso%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%amex%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%amount%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%amt%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%area%code%', 1, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%atm%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%atm%cards%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%atm%kaart%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%atmcard%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%atmcards%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%atmkaart%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%atmkaarten%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%ausweis%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)
	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%bancontact%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%bank%acc%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%bank%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%bank%routing%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%banking%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%bankkaart%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%bic%code%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%bic%num%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%birth%date%', 1, N'3de7cc52-710d-4e96-7e20-4d5188d2590c', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%birthday%', 1, N'3de7cc52-710d-4e96-7e20-4d5188d2590c', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%card%holder%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%card%identification%number%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%card%num%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%card%type%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%card%verification%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cardano%numerico%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cardi%la%verifica%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carta%bianca%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carta%credito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carta%di%credito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cartao%de%credito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cartao%de%crédito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cartão%de%credito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cartão%de%crédito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cartao%de%debito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cartao%de%débito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cartão%de%debito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cartão%de%débito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carte%bancaire%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carte%blanche%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carte%bleue%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carte%de%credit%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carte%de%crédit%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carte%di%credito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%carteblanche%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%ccn%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%check%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%chequekaart%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cirrus%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cirrus-edc-maestro%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%city%', 0, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%clinic%', 1, N'6e2c5b18-97cf-3073-27ab-f12f87493da7', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cod%seg%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cod%seguranca%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cod%segurança%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cód%seguranca%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cód%segurança%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cod%sicurezza%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cod.%seg%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cod.%seguranca%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cod.%segurança%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cód.%seguranca%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cód.%segurança%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cod.%sicurezza%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%code%sécu%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%codice%di%sicurezza%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%codice%di%verifica%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%codi%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%códi%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%codi%de%seguranca%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%codi%de%segurança%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%códi%de%seguranca%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%códi%de%segurança%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%compensation%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%controlekaart%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%credit%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%credit%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%crittogramma%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cryptogram%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cryptogramme%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%currency%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cv2%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cvc%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cvc2%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cvn%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%cvv%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%data%de%expiracao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%data%de%expiração%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%data%del%exp%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%data%di%exp%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%data%di%scadenza%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%data%em%que%expira%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%data%scad%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%data%scadenza%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%date%de%validité%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%date%of%birth%', 1, N'3de7cc52-710d-4e96-7e20-4d5188d2590c', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%datum%afloop%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%datum%van%exp%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%de%afloop%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%de%kaart%controle%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%debet%kaart%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%debit%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%debit%acc%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%debit%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%debito%automatico%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%débito%automático%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%diners%club%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%discover%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%discover%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%driver%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%e-mail%', 0, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%eigentümername%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%email%', 0, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%employeessn%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%espira%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%european%debit%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%exp%date%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%exp%datum%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%expiration%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%expire%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%expires%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%expiry%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%expm%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%expy%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%fecha%de%expiracion%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%fecha%de%venc%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%first%name%', 0, N'57845286-7598-22f5-9659-15b24aeb125e', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%fuehrerschein%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%fuhrerschein%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%führerschein%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%full%name%', 0, N'57845286-7598-22f5-9659-15b24aeb125e', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%geeft%nr%uit%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%gultig%bis%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%gültig%bis%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%gultigkeitsdatum%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%gültigkeitsdatum%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%health%', 1, N'6e2c5b18-97cf-3073-27ab-f12f87493da7', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%healthcondition%', 1, N'6e2c5b18-97cf-3073-27ab-f12f87493da7', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%hoofdkaart%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%hoofdkaarten%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%iban%code%', 0, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%iban%num%', 0, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%id%number%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%identificación%fiscal%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%identification%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%identifikation%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%identifizierungsnummer%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%identité%nationale%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%in%viaggio%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%insee%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%insurance%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%invoice%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%issue%no%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%issue%number%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%japanese%card%bureau%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%japanse%kaartdienst%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%jcb%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kaart%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kaart%num%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kaartaantal%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kaarthouder%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kaartidentificatienummer%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%karte%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%karteninhaber%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kartennr%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kartennummer%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kreditkarte%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kreditkartenprufnummer%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kreditkartenprüfnummer%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%kwestieaantal%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%last%name%', 0, N'57845286-7598-22f5-9659-15b24aeb125e', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%le%code%de%la%sécurité%sociale%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%le%numéro%d''identification%nationale%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%mac%address%', 0, N'b40ad280-0f6a-6ca8-11ba-2f1a08651fcf', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%maestro%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%maiden%name%', 0, N'57845286-7598-22f5-9659-15b24aeb125e', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%master%card%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%mastercard%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%medical%', 1, N'6e2c5b18-97cf-3073-27ab-f12f87493da7', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%medication%', 1, N'6e2c5b18-97cf-3073-27ab-f12f87493da7', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%mister%cash%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%mobile%', 1, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%n%carta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%n.%carta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nº%autorizzazione%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nº%carta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nº%de%carte%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nº%de%la%carte%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nº%de%tarjeta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nº%do%cartao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nº%do%cartão%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nº.%do%cartão%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%national%id%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no%de%tarjeta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no%do%cartao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no%do%cartão%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no%identite%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no%identité%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no.%de%tarjeta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no.%dell''edizione%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no.%di%sicurezza%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no.%do%cartao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no.%do%cartão%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no.%identite%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%no.%identité%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nr%carta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%nr.%carta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numeri%di%scheda%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%carta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numéro%d''assurance%sociale%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%de%cartao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%de%cartão%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%número%de%cartao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%número%de%cartão%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%de%carte%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numéro%de%carte%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numéro%de%sécu%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%de%securite%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numéro%de%sécurité%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numéro%de%sécurité%sociale%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%de%tarjeta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%número%de%tarjeta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%de%verificacao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%número%de%verificação%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%dell''edizione%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%della%carta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%di%carta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%di%identificazione%della%scheda%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%di%scheda%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%di%sicurezza%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%do%cartao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%do%cartão%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%número%do%cartao%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%identite%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numéro%identité%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%numero%van%veiligheid%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%pasaporte%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%pass%', 1, N'c64aba7b-3a3e-95b6-535d-3bc535da5a59', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%passeport%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%passport%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%password%', 1, N'c64aba7b-3a3e-95b6-535d-3bc535da5a59', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%patente%di%guida%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%patient%', 1, N'6e2c5b18-97cf-3073-27ab-f12f87493da7', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%payment%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%paypal%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%perno%il%blocco%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%personal%', 1, N'9c5b4809-0ccc-0637-6547-91a6f8bb609d', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%personalausweis%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%phone%', 1, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%pin%block%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%pmt%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%postal%', 1, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%prescription%', 1, N'6e2c5b18-97cf-3073-27ab-f12f87493da7', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%prufziffer%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%prüfziffer%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%pwd%', 1, N'c64aba7b-3a3e-95b6-535d-3bc535da5a59', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%reisepass%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%reset%code%', 1, N'c64aba7b-3a3e-95b6-535d-3bc535da5a59', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%routing%no%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%routing%number%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%savings%acc%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scadenza%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scheda%dell''assegno%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scheda%dell''atmosfera%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scheda%della%banca%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scheda%di%controllo%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scheda%di%debito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scheda%matrice%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%schede%dell''atmosfera%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%schede%di%controllo%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%schede%di%debito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%schede%matrici%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scoprono%la%scheda%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%scoprono%le%schede%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%securite%sociale%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%securité%sociale%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%security%', 1, N'9c5b4809-0ccc-0637-6547-91a6f8bb609d', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%security%code%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%security%no%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%security%number%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%sicherheits%kode%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%sicherheitscode%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%sicherheitsnummer%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%soc%sec%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%social%security%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%solo%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%speldblok%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%ss_num%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%ssnum%', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%street%', 0, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%supporti%di%scheda%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%supporto%di%scheda%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%surname%', 0, N'57845286-7598-22f5-9659-15b24aeb125e', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%swift%code%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%swift%num%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%swift%routing%', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%switch%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjeta%atm%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjeta%credito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjeta%crédito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjeta%de%atm%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjeta%de%credito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjeta%de%debito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjeta%debito%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjeta%no%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tarjetahabiente%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tax%', 1, N'c44193e1-0e58-4b2a-9001-f7d6e7bc1373', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tax%id%', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%tipo%della%scheda%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%treatment%', 1, N'6e2c5b18-97cf-3073-27ab-f12f87493da7', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%ufficio%giapponese%della%scheda%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%user%acc%', 1, N'c64aba7b-3a3e-95b6-535d-3bc535da5a59', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%username%', 1, N'c64aba7b-3a3e-95b6-535d-3bc535da5a59', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%v%pay%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%valable%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%validade%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%valido%hasta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%válido%hasta%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%valor%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%veiligheid%nr%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%veiligheidsaantal%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%veiligheidscode%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%veiligheidsnummer%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%venc%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%vencimento%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%vencimiento%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%verfalldatum%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%verloopt%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%vervaldag%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%vervaldatum%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%visa%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%visa%electron%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%visa%plus%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%visto%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%vto%', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'%zip%', 1, N'5c503e21-22c6-81fa-620b-f369b8ec38d1', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'aba', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'cid', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'dob', 1, N'3de7cc52-710d-4e96-7e20-4d5188d2590c', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'iban', 1, N'8a462631-4130-0a31-9a52-c6a9ca125f92', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'ip', 0, N'b40ad280-0f6a-6ca8-11ba-2f1a08651fcf', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'ip%address%', 0, N'b40ad280-0f6a-6ca8-11ba-2f1a08651fcf', 1)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'itin', 1, N'6f5a11a7-08b1-19c3-59e5-8c89cf4f8444', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'mc', 1, N'd22fa6e9-5ee4-3bde-4c2b-a409604c4646', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'sin', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'ssid', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 0)

	INSERT [DC].[KeyWords] ([KeywordName], [CanBeNumeric], [InfoTypeId], [ShouldLike]) VALUES (N'ssn', 1, N'd936ec2c-04a4-9cf7-44c2-378a96456c61', 0)
END
GO

GO
PRINT N'Checking existing data against newly created constraints';


GO
ALTER TABLE [DC].[KeyWords] WITH CHECK CHECK CONSTRAINT [FK_KeyWords_InformationType];

ALTER TABLE [DC].[InformationType] WITH CHECK CHECK CONSTRAINT [FK_InformationType_SensitiveName];


GO
PRINT N'Update complete.';


GO
