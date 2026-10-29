-- Column-name patterns (LIKE syntax, compared case-insensitively) that point to an information type.
-- CanBeNumeric = 0 skips columns of numeric types, so that AddressId isn't taken for an address.
CREATE TABLE [DC].[KeyWords]
(
    [InfoTypeId]   UNIQUEIDENTIFIER NOT NULL,
    [KeywordName]  NVARCHAR (128)   COLLATE Latin1_General_100_BIN2 NOT NULL,
    [CanBeNumeric] BIT              NOT NULL,
    CONSTRAINT [PK_KeyWords] PRIMARY KEY CLUSTERED ([InfoTypeId], [KeywordName]),
    CONSTRAINT [FK_KeyWords_InformationType] FOREIGN KEY ([InfoTypeId]) REFERENCES [DC].[InformationType] ([InfoTypeId]) ON DELETE CASCADE
);
