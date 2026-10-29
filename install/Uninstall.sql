-- Removes the DC schema and everything in it, from version 1 or 2 of this project, from the
-- current database. Classifications already on columns stay; to remove them as well, run
-- EXECUTE DC.RemoveClassification; before this script.
SET NOCOUNT ON;
GO
DROP PROCEDURE IF EXISTS DC.AcceptSuggestions;
DROP PROCEDURE IF EXISTS DC.RemoveClassification;
DROP PROCEDURE IF EXISTS DC.MigrateLegacyClassification;
DROP PROCEDURE IF EXISTS DC.ImportPolicy;
DROP PROCEDURE IF EXISTS DC.AddSensitivityClassification;
DROP PROCEDURE IF EXISTS DC.DropSensitivityClassification;
DROP VIEW IF EXISTS DC.GetIntermediateResults;
DROP VIEW IF EXISTS DC.GetMatchingColumns;
DROP VIEW IF EXISTS DC.GetClassifiedColumns;
DROP VIEW IF EXISTS DC.GetLegacyClassifiedColumns;
DROP FUNCTION IF EXISTS DC.AddClassificationStatement;
DROP TABLE IF EXISTS DC.KeyWords;
DROP TABLE IF EXISTS DC.InformationType;
DROP TABLE IF EXISTS DC.SensitiveName;
GO
IF SCHEMA_ID(N'DC') IS NOT NULL
    DROP SCHEMA DC;
GO
