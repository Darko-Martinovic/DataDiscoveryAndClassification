-- The suggestions: one information type and its recommended label for each matching column
-- that isn't classified yet. DC.AcceptSuggestions applies them.
CREATE VIEW [DC].[GetIntermediateResults]
AS
WITH Ranked AS
(
    SELECT
        MC.SchemaName,
        MC.TableName,
        MC.ColumnName,
        MC.TableObjectId,
        MC.ColumnId,
        IT.InfoTypeId,
        IT.InfoTypeName,
        SN.LabelId,
        SN.LabelName,
        SN.LabelRank,
        ROW_NUMBER() OVER (
            PARTITION BY MC.TableObjectId, MC.ColumnId
            ORDER BY IT.InfoTypeOrder, IT.InfoTypeName) AS Choice
    FROM DC.GetMatchingColumns AS MC
        INNER JOIN DC.InformationType AS IT
            ON IT.InfoTypeId = MC.InfoTypeId
        LEFT JOIN DC.SensitiveName AS SN
            ON SN.LabelId = IT.RecommendedLabelId
)
SELECT
    R.SchemaName,
    R.TableName,
    R.ColumnName,
    R.InfoTypeId   AS InformationTypeId,
    R.InfoTypeName AS InformationTypeName,
    R.LabelId      AS SensitivityLabelId,
    R.LabelName    AS SensitivityLabelName,
    R.LabelRank    AS SensitivityRank
FROM Ranked AS R
WHERE R.Choice = 1
    AND NOT EXISTS
    (
        SELECT 1
        FROM sys.sensitivity_classifications AS SC
        WHERE SC.class = 1
            AND SC.major_id = R.TableObjectId
            AND SC.minor_id = R.ColumnId
    );
