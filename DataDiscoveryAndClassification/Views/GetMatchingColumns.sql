CREATE VIEW DC.GetMatchingColumns
as
SELECT DISTINCT
	name
   ,CanBeNumeric
   ,InfoTypeId
   ,KeyWordName
FROM (SELECT DISTINCT
		LOWER(name) AS name
	FROM sys.columns) AS Columns
INNER JOIN DC.KeyWords
	ON (ShouldLike = 0
			AND name COLLATE Latin1_GENERAL_BIN = KeywordName COLLATE Latin1_GENERAL_BIN)
		OR (ShouldLike = 1
			AND name COLLATE Latin1_GENERAL_BIN LIKE KeywordName COLLATE Latin1_GENERAL_BIN)

