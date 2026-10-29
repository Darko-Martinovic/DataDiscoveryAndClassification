-- Runs after tests/Tests.sql and install/Uninstall.sql.
:on error exit
SET NOCOUNT ON;
GO
DECLARE @a AS NVARCHAR (4000);
SET @a = (SELECT COUNT(*) FROM sys.objects WHERE schema_id = SCHEMA_ID(N'DC'));
EXECUTE test.AssertEqual N'Uninstall.sql removes the DC objects', N'0', @a;
SET @a = IIF(SCHEMA_ID(N'DC') IS NULL, N'gone', N'still there');
EXECUTE test.AssertEqual N'Uninstall.sql removes the DC schema', N'gone', @a;
SET @a = (SELECT COUNT(*) FROM sys.sensitivity_classifications);
EXECUTE test.AssertEqual N'Uninstall.sql keeps the classifications', N'2', @a;
GO
PRINT N'Uninstall tests passed.';
GO
