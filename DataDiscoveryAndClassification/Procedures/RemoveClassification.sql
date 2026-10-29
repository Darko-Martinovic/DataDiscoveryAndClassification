-- Removes the classification of every classified column in the database, whoever added it
-- (this project, SSMS or T-SQL). History tables lose theirs with their current table.
-- Needs the ALTER ANY SENSITIVITY CLASSIFICATION permission (implied by ALTER on the database).
CREATE PROCEDURE [DC].[RemoveClassification]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @statement AS NVARCHAR (MAX);
    DECLARE @removed AS INT = 0;

    DECLARE Classified CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
        SELECT N'DROP SENSITIVITY CLASSIFICATION FROM '
            + QUOTENAME(SchemaName) + N'.' + QUOTENAME(TableName) + N'.' + QUOTENAME(ColumnName) + N';'
        FROM DC.GetClassifiedColumns
        WHERE IsHistoryTable = 0;

    BEGIN TRANSACTION;

    OPEN Classified;
    FETCH NEXT FROM Classified INTO @statement;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXECUTE sys.sp_executesql @statement;
        SET @removed += 1;
        FETCH NEXT FROM Classified INTO @statement;
    END;
    CLOSE Classified;
    DEALLOCATE Classified;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'Removed the classification of ', @removed, N' column(s).');
END;
