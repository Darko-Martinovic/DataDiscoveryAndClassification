--== Remove extended properties ==--
EXEC DC.RemoveClassification
GO
--== Drop foreign keys ==--
IF EXISTS (SELECT * 
  FROM sys.foreign_keys 
   WHERE object_id = OBJECT_ID(N'DC.FK_KeyWords_InformationType')
   AND parent_object_id = OBJECT_ID(N'DC.KeyWords')
)
ALTER TABLE [DC].[KeyWords] DROP CONSTRAINT [FK_KeyWords_InformationType]
GO

IF EXISTS (SELECT * 
  FROM sys.foreign_keys 
   WHERE object_id = OBJECT_ID(N'DC.FK_InformationType_SensitiveName')
   AND parent_object_id = OBJECT_ID(N'DC.InformationType')
)
ALTER TABLE [DC].[InformationType] DROP CONSTRAINT [FK_InformationType_SensitiveName]
GO
--== Drop views ==--
IF object_id(N'DC.GetMatchingColumns', 'V') IS NOT NULL
	DROP VIEW DC.GetMatchingColumns
GO

IF object_id(N'DC.GetIntermediateResults', 'V') IS NOT NULL
	DROP VIEW DC.GetIntermediateResults
GO

IF object_id(N'DC.GetClassifiedColumns', 'V') IS NOT NULL
	DROP VIEW DC.GetClassifiedColumns
GO

--== Drop the procedure ==--
IF OBJECT_ID(N'DC.AcceptSuggestions','P') IS NOT NULL 
	DROP PROCEDURE DC.AcceptSuggestions
GO
IF OBJECT_ID(N'DC.RemoveClassification','P') IS NOT NULL 
	DROP PROCEDURE DC.RemoveClassification
GO
IF OBJECT_ID(N'DC.AddSensitivityClassification','P') IS NOT NULL 
	DROP PROCEDURE DC.AddSensitivityClassification
GO
IF OBJECT_ID(N'DC.DropSensitivityClassification','P') IS NOT NULL 
	DROP PROCEDURE DC.DropSensitivityClassification
GO

--== Drop tables ==--
IF object_id(N'DC.SensitiveName', 'U') IS NOT NULL
DROP TABLE [DC].[SensitiveName]
GO
IF object_id(N'DC.KeyWords', 'U') IS NOT NULL
DROP TABLE [DC].[KeyWords]
GO
IF object_id(N'DC.InformationType', 'U') IS NOT NULL
DROP TABLE [DC].[InformationType]
GO

--== Drop the schema ==--
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'DC')
DROP SCHEMA DC
GO

