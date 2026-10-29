-- Replaces the labels, information types and keywords with those of an Information Protection
-- policy file, the JSON that SSMS exports and reads (Tasks > Data Discovery and Classification).
-- Disabled labels and information types and excluded keywords are left out.
-- Classifications already on columns aren't touched.
CREATE PROCEDURE [DC].[ImportPolicy]
    @Policy NVARCHAR (MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- A file read as text may start with a byte order mark.
    IF LEFT(@Policy, 1) = NCHAR(65279)
        SET @Policy = STUFF(@Policy, 1, 1, N'');

    IF ISJSON(@Policy) = 0
        OR JSON_QUERY(@Policy, N'$.Labels') IS NULL
        OR JSON_QUERY(@Policy, N'$.InformationTypes') IS NULL
        THROW 50000, N'The policy must be a JSON object with Labels and InformationTypes, like the Information Protection policy file SSMS exports.', 1;

    BEGIN TRANSACTION;

    DELETE FROM DC.KeyWords;
    DELETE FROM DC.InformationType;
    DELETE FROM DC.SensitiveName;

    INSERT INTO DC.SensitiveName (LabelId, LabelName, LabelOrder, LabelRank)
    SELECT
        CONVERT(UNIQUEIDENTIFIER, L.[key]),
        D.DisplayName,
        D.[Order],
        UPPER(ISNULL(D.[Rank], N'None'))
    FROM OPENJSON(@Policy, N'$.Labels') AS L
        CROSS APPLY OPENJSON(L.value)
        WITH
        (
            DisplayName NVARCHAR (128),
            [Rank]      NVARCHAR (10),
            [Order]     INT,
            Enabled     BIT
        ) AS D
    WHERE ISNULL(D.Enabled, 1) = 1;

    INSERT INTO DC.InformationType (InfoTypeId, InfoTypeName, InfoTypeOrder, RecommendedLabelId)
    SELECT
        CONVERT(UNIQUEIDENTIFIER, I.[key]),
        D.DisplayName,
        D.[Order],
        SN.LabelId
    FROM OPENJSON(@Policy, N'$.InformationTypes') AS I
        CROSS APPLY OPENJSON(I.value)
        WITH
        (
            DisplayName        NVARCHAR (128),
            [Order]            INT,
            RecommendedLabelId UNIQUEIDENTIFIER,
            Enabled            BIT
        ) AS D
        LEFT JOIN DC.SensitiveName AS SN
            ON SN.LabelId = D.RecommendedLabelId
    WHERE ISNULL(D.Enabled, 1) = 1;

    INSERT INTO DC.KeyWords (InfoTypeId, KeywordName, CanBeNumeric)
    SELECT
        IT.InfoTypeId,
        K.Pattern COLLATE Latin1_General_100_BIN2,
        MAX(CAST(ISNULL(K.CanBeNumeric, 1) AS INT))
    FROM OPENJSON(@Policy, N'$.InformationTypes') AS I
        INNER JOIN DC.InformationType AS IT
            ON IT.InfoTypeId = CONVERT(UNIQUEIDENTIFIER, I.[key])
        CROSS APPLY OPENJSON(I.value, N'$.Keywords')
        WITH
        (
            Pattern      NVARCHAR (128),
            CanBeNumeric BIT,
            Excluded     BIT
        ) AS K
    WHERE K.Pattern IS NOT NULL
        AND ISNULL(K.Excluded, 0) = 0
    GROUP BY IT.InfoTypeId, K.Pattern COLLATE Latin1_General_100_BIN2;

    COMMIT TRANSACTION;

    DECLARE @summary AS NVARCHAR (200) = CONCAT(
        N'Imported ', (SELECT COUNT(*) FROM DC.SensitiveName), N' labels, ',
        (SELECT COUNT(*) FROM DC.InformationType), N' information types and ',
        (SELECT COUNT(*) FROM DC.KeyWords), N' keywords.');
    PRINT @summary;
END;
