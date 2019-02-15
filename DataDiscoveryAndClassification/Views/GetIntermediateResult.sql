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
		AND -- That is the way how Microsoft get rid of columns such as AddressId. 
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
WHERE IR.SchemaName <> 'DC' --Exclude the DC schema
)
SELECT * FROM Result IR
WHERE NOT EXISTS
( SELECT * FROM DC.GetClassifiedColumns GCC 
   WHERE IR.SchemaName = GCC.SchemaName AND IR.TableName = GCC.TableName AND IR.ColumnName = GCC.ColumnName
   ) 
go
