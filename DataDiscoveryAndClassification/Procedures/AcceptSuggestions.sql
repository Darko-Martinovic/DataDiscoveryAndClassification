-- Classifies every column in DC.GetIntermediateResults with its suggested information type,
-- label and rank. All the columns are classified, or none.
-- Needs the ALTER ANY SENSITIVITY CLASSIFICATION permission (implied by ALTER on the database).
CREATE PROCEDURE [DC].[AcceptSuggestions]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @statement AS NVARCHAR (MAX);
    DECLARE @classified AS INT = 0;

    DECLARE Suggestions CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
        SELECT DC.AddClassificationStatement(
            SchemaName,
            TableName,
            ColumnName,
            SensitivityLabelName,
            LOWER(CONVERT(NVARCHAR (36), SensitivityLabelId)),
            InformationTypeName,
            LOWER(CONVERT(NVARCHAR (36), InformationTypeId)),
            SensitivityRank)
        FROM DC.GetIntermediateResults;

    BEGIN TRANSACTION;

    OPEN Suggestions;
    FETCH NEXT FROM Suggestions INTO @statement;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXECUTE sys.sp_executesql @statement;
        SET @classified += 1;
        FETCH NEXT FROM Suggestions INTO @statement;
    END;
    CLOSE Suggestions;
    DEALLOCATE Suggestions;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'Classified ', @classified, N' column(s).');
END;
