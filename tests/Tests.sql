-- Tests for an empty database with install/Install.sql (or the dacpac) deployed in it.
-- Run by tests/run.sh with sqlcmd; the first failure stops the run. Kept to ASCII so that
-- every sqlcmd reads it alike: NCHAR() stands in for other characters.
:on error exit
SET NOCOUNT ON;
GO
CREATE SCHEMA test;
GO
CREATE PROCEDURE test.AssertEqual
    @Test     NVARCHAR (200),
    @Expected NVARCHAR (4000),
    @Actual   NVARCHAR (4000)
AS
BEGIN
    IF (@Expected IS NULL AND @Actual IS NULL) OR @Expected = @Actual
        PRINT N'ok   ' + @Test;
    ELSE
    BEGIN
        DECLARE @message AS NVARCHAR (2048) = CONCAT(
            N'FAIL ', @Test, N': expected ', ISNULL(@Expected, N'NULL'), N', got ', ISNULL(@Actual, N'NULL'));
        THROW 50001, @message, 1;
    END;
END;
GO
-- A column's classification as one string: type | label | rank | type id | label id, NULLs left out.
CREATE FUNCTION test.Classification (@Schema SYSNAME, @Table SYSNAME, @Column SYSNAME)
RETURNS NVARCHAR (4000)
AS
BEGIN
    RETURN
    (
        SELECT CONCAT_WS(N' | ', InformationType, SensitivityLabel, SensitivityRank, InformationTypeId, SensitivityLabelId)
        FROM DC.GetClassifiedColumns
        WHERE SchemaName = @Schema AND TableName = @Table AND ColumnName = @Column
    );
END;
GO
CREATE FUNCTION test.Suggestions ()
RETURNS NVARCHAR (4000)
AS
BEGIN
    RETURN
    (
        SELECT STRING_AGG(CONCAT(SchemaName, N'.', TableName, N'.', ColumnName, N'=', InformationTypeName, N'/', ISNULL(SensitivityLabelName, N'-')), N', ')
            WITHIN GROUP (ORDER BY SchemaName, TableName, ColumnName)
        FROM DC.GetIntermediateResults
    );
END;
GO

PRINT N'-- The seed is Microsoft''s default policy';
DECLARE @a AS NVARCHAR (4000);
SET @a = (SELECT COUNT(*) FROM DC.SensitiveName);
EXECUTE test.AssertEqual N'6 labels', N'6', @a;
SET @a = (SELECT COUNT(*) FROM DC.InformationType);
EXECUTE test.AssertEqual N'12 information types', N'12', @a;
SET @a = (SELECT COUNT(*) FROM DC.KeyWords);
EXECUTE test.AssertEqual N'361 keywords, each once per type', N'361', @a;
SET @a = (SELECT COUNT(*) FROM DC.KeyWords WHERE KeywordName = N'%num' + NCHAR(233) + N'ro%d''assurance%sociale%');
EXECUTE test.AssertEqual N'keywords keep apostrophes and accents', N'1', @a;
SET @a = (SELECT LabelRank FROM DC.SensitiveName WHERE LabelName = N'Highly Confidential - GDPR');
EXECUTE test.AssertEqual N'labels keep their rank', N'HIGH', @a;
GO

PRINT N'-- DC.AddClassificationStatement';
DECLARE @a AS NVARCHAR (4000);
SET @a = DC.AddClassificationStatement(N'a]b', N'c', N'd''e', N'It''s', NULL, NULL, N'x', N'high');
EXECUTE test.AssertEqual N'quotes names, escapes values, leaves out NULLs',
    N'ADD SENSITIVITY CLASSIFICATION TO [a]]b].[c].[d''e] WITH (LABEL = N''It''''s'', INFORMATION_TYPE_ID = N''x'', RANK = HIGH);', @a;
SET @a = DC.AddClassificationStatement(N'a', N'b', N'c', N'Public', NULL, NULL, NULL, N'URGENT');
EXECUTE test.AssertEqual N'ignores an unknown rank', N'ADD SENSITIVITY CLASSIFICATION TO [a].[b].[c] WITH (LABEL = N''Public'');', @a;
SET @a = DC.AddClassificationStatement(N'a', N'b', N'c', NULL, NULL, NULL, NULL, NULL);
EXECUTE test.AssertEqual N'nothing to add gives NULL', NULL, @a;
GO

PRINT N'-- Suggestions and DC.AcceptSuggestions';
GO
CREATE SCHEMA Sales;
GO
CREATE TABLE Sales.Customer
(
    CustomerId       INT            NOT NULL PRIMARY KEY,
    FirstName        NVARCHAR (50)  NOT NULL,
    LastName         NVARCHAR (50)  NOT NULL,
    FullName         AS FirstName + N' ' + LastName,
    Email            NVARCHAR (100) NULL,
    AddressId        INT            NULL,
    HomeAddress      NVARCHAR (200) NULL,
    CreditCardNumber VARCHAR (20)   NULL,
    HasCreditCard    BIT            NOT NULL,
    DOB              DATE           NULL,
    AccountPassword  NVARCHAR (100) NULL
);
CREATE TABLE Sales.Payment
(
    PaymentId INT       NOT NULL PRIMARY KEY,
    Amount    MONEY     NOT NULL,
    ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo   DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Sales.PaymentHistory));
GO
CREATE SCHEMA [odd ]] schema];
GO
CREATE TABLE [odd ]] schema].[it's ]] table] ([e-mail ']] address] NVARCHAR (100) NULL);
GO
ADD SENSITIVITY CLASSIFICATION TO Sales.Customer.LastName WITH (LABEL = N'Public', RANK = NONE);
GO
DECLARE @a AS NVARCHAR (4000) = test.Suggestions();
EXECUTE test.AssertEqual N'suggests the lowest-order type for each unclassified column; skips numeric address ids, bit and computed columns and history tables',
    N'odd ] schema.it''s ] table.e-mail ''] address=Contact Info/Confidential, Sales.Customer.AccountPassword=Credentials/Confidential, Sales.Customer.CreditCardNumber=Credit Card/Confidential, Sales.Customer.DOB=Date Of Birth/Confidential - GDPR, Sales.Customer.Email=Contact Info/Confidential, Sales.Customer.FirstName=Name/Confidential - GDPR, Sales.Customer.HomeAddress=Contact Info/Confidential, Sales.Payment.Amount=Financial/Confidential, Sales.Payment.PaymentId=Financial/Confidential',
    @a;
GO
EXECUTE DC.AcceptSuggestions;
GO
DECLARE @a AS NVARCHAR (4000);
SET @a = test.Classification(N'Sales', N'Customer', N'Email');
EXECUTE test.AssertEqual N'classifies with type, label, rank and lowercase ids',
    N'Contact Info | Confidential | MEDIUM | 5c503e21-22c6-81fa-620b-f369b8ec38d1 | 331f0b13-76b5-2f1b-a77b-def5a73c73c2', @a;
SET @a = test.Classification(N'Sales', N'Customer', N'FirstName');
EXECUTE test.AssertEqual N'GDPR types get the GDPR label',
    N'Name | Confidential - GDPR | MEDIUM | 57845286-7598-22f5-9659-15b24aeb125e | 989adc05-3f3f-0588-a635-f475b994915b', @a;
SET @a = test.Classification(N'odd ] schema', N'it''s ] table', N'e-mail ''] address');
EXECUTE test.AssertEqual N'classifies odd names',
    N'Contact Info | Confidential | MEDIUM | 5c503e21-22c6-81fa-620b-f369b8ec38d1 | 331f0b13-76b5-2f1b-a77b-def5a73c73c2', @a;
SET @a = test.Classification(N'Sales', N'Customer', N'LastName');
EXECUTE test.AssertEqual N'leaves an existing classification alone', N'Public | NONE', @a;
SET @a = test.Classification(N'Sales', N'PaymentHistory', N'Amount');
EXECUTE test.AssertEqual N'a history table takes its current table''s classification',
    N'Financial | Confidential | MEDIUM | c44193e1-0e58-4b2a-9001-f7d6e7bc1373 | 331f0b13-76b5-2f1b-a77b-def5a73c73c2', @a;
SET @a = (SELECT COUNT(*) FROM DC.GetIntermediateResults);
EXECUTE test.AssertEqual N'no suggestions left', N'0', @a;
GO
EXECUTE DC.AcceptSuggestions;
DECLARE @a AS NVARCHAR (4000) = (SELECT COUNT(*) FROM DC.GetClassifiedColumns WHERE IsHistoryTable = 0);
EXECUTE test.AssertEqual N'accepting again changes nothing', N'10', @a;
GO

PRINT N'-- Legacy classifications and DC.MigrateLegacyClassification';
GO
CREATE SCHEMA Legacy;
GO
CREATE TABLE Legacy.Person
(
    PersonId INT           NOT NULL PRIMARY KEY,
    Phone    NVARCHAR (20) NULL,
    Nickname NVARCHAR (50) NULL,
    Mobile   NVARCHAR (20) NULL,
    Twice    AS PersonId * 2
);
GO
CREATE PROCEDURE test.AddLegacy @Column SYSNAME, @Name SYSNAME, @Value NVARCHAR (128)
AS
EXECUTE sys.sp_addextendedproperty
    @name = @Name, @value = @Value,
    @level0type = N'SCHEMA', @level0name = N'Legacy',
    @level1type = N'TABLE', @level1name = N'Person',
    @level2type = N'COLUMN', @level2name = @Column;
GO
EXECUTE test.AddLegacy N'Phone', N'sys_information_type_name', N'Contact Info';
EXECUTE test.AddLegacy N'Phone', N'sys_information_type_id', N'5c503e21-22c6-81fa-620b-f369b8ec38d1';
EXECUTE test.AddLegacy N'Phone', N'sys_sensitivity_label_name', N'Confidential';
EXECUTE test.AddLegacy N'Phone', N'sys_sensitivity_label_id', N'331f0b13-76b5-2f1b-a77b-def5a73c73c2';
EXECUTE test.AddLegacy N'Nickname', N'sys_information_type_name', N'Other';
EXECUTE test.AddLegacy N'Nickname', N'sys_sensitivity_label_name', N'Highly Confidential';
EXECUTE test.AddLegacy N'Mobile', N'sys_sensitivity_label_name', N'Public';
EXECUTE test.AddLegacy N'Twice', N'sys_sensitivity_label_name', N'Public';
ADD SENSITIVITY CLASSIFICATION TO Legacy.Person.Mobile WITH (LABEL = N'General', RANK = LOW);
GO
DECLARE @a AS NVARCHAR (4000) = (SELECT COUNT(*) FROM DC.GetLegacyClassifiedColumns);
EXECUTE test.AssertEqual N'finds the legacy classifications', N'4', @a;
GO
EXECUTE DC.MigrateLegacyClassification;
GO
DECLARE @a AS NVARCHAR (4000);
SET @a = test.Classification(N'Legacy', N'Person', N'Phone');
EXECUTE test.AssertEqual N'migrates all four properties, with the rank of the label id',
    N'Contact Info | Confidential | MEDIUM | 5c503e21-22c6-81fa-620b-f369b8ec38d1 | 331f0b13-76b5-2f1b-a77b-def5a73c73c2', @a;
SET @a = test.Classification(N'Legacy', N'Person', N'Nickname');
EXECUTE test.AssertEqual N'migrates names alone, with the rank of the label name', N'Other | Highly Confidential | HIGH', @a;
SET @a = test.Classification(N'Legacy', N'Person', N'Mobile');
EXECUTE test.AssertEqual N'keeps a newer classification', N'General | LOW', @a;
SET @a = test.Classification(N'Legacy', N'Person', N'Twice');
EXECUTE test.AssertEqual N'skips computed columns', NULL, @a;
SET @a = (SELECT COUNT(*) FROM sys.extended_properties WHERE name LIKE N'sys[_]%');
EXECUTE test.AssertEqual N'keeps the extended properties by default', N'8', @a;
GO
EXECUTE DC.MigrateLegacyClassification @DropLegacy = 1;
DECLARE @a AS NVARCHAR (4000);
SET @a = (SELECT COUNT(*) FROM sys.extended_properties WHERE name LIKE N'sys[_]%');
EXECUTE test.AssertEqual N'@DropLegacy = 1 drops them', N'0', @a;
SET @a = (SELECT COUNT(*) FROM DC.GetLegacyClassifiedColumns);
EXECUTE test.AssertEqual N'no legacy classifications left', N'0', @a;
GO

PRINT N'-- DC.ImportPolicy';
DECLARE @a AS NVARCHAR (4000);
BEGIN TRY
    EXECUTE DC.ImportPolicy @Policy = N'{"Labels": {}}';
    SET @a = N'no error';
END TRY
BEGIN CATCH
    SET @a = ERROR_NUMBER();
END CATCH;
EXECUTE test.AssertEqual N'refuses a policy without information types', N'50000', @a;
SET @a = (SELECT COUNT(*) FROM DC.KeyWords);
EXECUTE test.AssertEqual N'a refused policy changes nothing', N'361', @a;
GO
-- Starts with a byte order mark, as a policy read from a file may.
DECLARE @policy AS NVARCHAR (MAX) = NCHAR(65279) + N'{
  "Labels": {
    "0f6c1f5e-0000-4000-8000-000000000001": { "DisplayName": "Owner''s eyes only", "Rank": "Critical", "Order": 100, "Enabled": true },
    "0f6c1f5e-0000-4000-8000-000000000002": { "DisplayName": "Retired", "Rank": "Low", "Order": 200, "Enabled": false }
  },
  "InformationTypes": {
    "0f6c1f5e-0000-4000-8000-000000000011": {
      "DisplayName": "Pet", "Order": 100, "RecommendedLabelId": "0f6c1f5e-0000-4000-8000-000000000001", "Enabled": true,
      "Keywords": [
        { "Pattern": "%DOG%", "CanBeNumeric": false, "Excluded": null },
        { "Pattern": "%cat%", "CanBeNumeric": true, "Excluded": true }
      ]
    },
    "0f6c1f5e-0000-4000-8000-000000000012": {
      "DisplayName": "Hobby", "Order": 200, "RecommendedLabelId": "0f6c1f5e-0000-4000-8000-000000000002", "Enabled": true,
      "Keywords": [ { "Pattern": "%hobby%", "CanBeNumeric": true } ]
    },
    "0f6c1f5e-0000-4000-8000-000000000013": {
      "DisplayName": "Old", "Order": 300, "Enabled": false,
      "Keywords": [ { "Pattern": "%old%", "CanBeNumeric": true } ]
    }
  }
}';
EXECUTE DC.ImportPolicy @Policy = @policy;
GO
DECLARE @a AS NVARCHAR (4000);
SET @a = (SELECT COUNT(*) FROM DC.SensitiveName);
EXECUTE test.AssertEqual N'imports enabled labels only', N'1', @a;
SET @a = (SELECT COUNT(*) FROM DC.InformationType);
EXECUTE test.AssertEqual N'imports enabled types only', N'2', @a;
SET @a = (SELECT COUNT(*) FROM DC.KeyWords);
EXECUTE test.AssertEqual N'leaves out excluded keywords', N'2', @a;
GO
CREATE TABLE Sales.Pet
(
    PetId   INT           NOT NULL PRIMARY KEY,
    DogName NVARCHAR (50) NULL,
    DogId   INT           NULL,
    CatName NVARCHAR (50) NULL,
    Hobby   NVARCHAR (50) NULL,
    OldName NVARCHAR (50) NULL
);
GO
DECLARE @a AS NVARCHAR (4000) = test.Suggestions();
EXECUTE test.AssertEqual N'matches keywords whatever their case; a type whose label is disabled has none',
    N'Sales.Pet.DogName=Pet/Owner''s eyes only, Sales.Pet.Hobby=Hobby/-', @a;
GO
EXECUTE DC.AcceptSuggestions;
GO
DECLARE @a AS NVARCHAR (4000);
SET @a = test.Classification(N'Sales', N'Pet', N'DogName');
EXECUTE test.AssertEqual N'classifies with the imported label and rank',
    N'Pet | Owner''s eyes only | CRITICAL | 0f6c1f5e-0000-4000-8000-000000000011 | 0f6c1f5e-0000-4000-8000-000000000001', @a;
SET @a = test.Classification(N'Sales', N'Pet', N'Hobby');
EXECUTE test.AssertEqual N'a type without a label is classified with the type alone',
    N'Hobby | 0f6c1f5e-0000-4000-8000-000000000012', @a;
GO

PRINT N'-- DC.RemoveClassification';
EXECUTE DC.RemoveClassification;
DECLARE @a AS NVARCHAR (4000) = (SELECT COUNT(*) FROM DC.GetClassifiedColumns);
EXECUTE test.AssertEqual N'removes every classification, history tables included', N'0', @a;
GO

-- Leave classifications behind for tests/AfterUninstall.sql.
EXECUTE DC.AcceptSuggestions;
GO
PRINT N'All tests passed.';
GO
