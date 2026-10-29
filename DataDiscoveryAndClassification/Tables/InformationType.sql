-- Information types: what kind of data a column holds, and the label recommended for it.
-- When a column matches keywords of several types, the type with the lowest InfoTypeOrder wins.
CREATE TABLE [DC].[InformationType]
(
    [InfoTypeId]         UNIQUEIDENTIFIER NOT NULL,
    [InfoTypeName]       NVARCHAR (128)   NOT NULL,
    [InfoTypeOrder]      INT              NOT NULL,
    [RecommendedLabelId] UNIQUEIDENTIFIER NULL,
    CONSTRAINT [PK_InformationType] PRIMARY KEY CLUSTERED ([InfoTypeId]),
    CONSTRAINT [FK_InformationType_SensitiveName] FOREIGN KEY ([RecommendedLabelId]) REFERENCES [DC].[SensitiveName] ([LabelId])
);
GO

CREATE UNIQUE INDEX [IX_InformationType_InfoTypeName] ON [DC].[InformationType] ([InfoTypeName]);
