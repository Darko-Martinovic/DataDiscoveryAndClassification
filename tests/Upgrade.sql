-- Runs on a database where version 1 (tag v1-article) classified columns in extended properties,
-- after install/Uninstall.sql removed version 1 and install/Install.sql put version 2 in.
:on error exit
SET NOCOUNT ON;
GO
DECLARE @legacy AS INT = (SELECT COUNT(*) FROM DC.GetLegacyClassifiedColumns);
IF @legacy <> 2
    THROW 50001, N'FAIL version 1 should have left 2 legacy classifications', 1;
PRINT N'ok   version 1 left 2 legacy classifications';
GO
EXECUTE DC.MigrateLegacyClassification @DropLegacy = 1;
GO
DECLARE @classification AS NVARCHAR (4000) =
(
    SELECT CONCAT_WS(N' | ', InformationType, SensitivityLabel, SensitivityRank)
    FROM DC.GetClassifiedColumns
    WHERE SchemaName = N'dbo' AND TableName = N'Contact' AND ColumnName = N'Email'
);
IF ISNULL(@classification, N'') <> N'Contact Info | Confidential | MEDIUM'
    THROW 50001, N'FAIL Email should be classified as Contact Info | Confidential | MEDIUM', 1;
PRINT N'ok   migrates version 1''s classifications';
IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE name LIKE N'sys[_]%')
    THROW 50001, N'FAIL the extended properties should be gone', 1;
PRINT N'ok   drops version 1''s extended properties';
PRINT N'Upgrade tests passed.';
GO
