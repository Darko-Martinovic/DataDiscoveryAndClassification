-- Sensitivity labels: how sensitive the data in a column is.
CREATE TABLE [DC].[SensitiveName]
(
    [LabelId]    UNIQUEIDENTIFIER NOT NULL,
    [LabelName]  NVARCHAR (128)   NOT NULL,
    [LabelOrder] INT              NOT NULL,
    [LabelRank]  NVARCHAR (10)    NOT NULL CONSTRAINT [DF_SensitiveName_LabelRank] DEFAULT (N'NONE'),
    CONSTRAINT [PK_SensitiveName] PRIMARY KEY CLUSTERED ([LabelId]),
    CONSTRAINT [CK_SensitiveName_LabelRank] CHECK ([LabelRank] IN (N'NONE', N'LOW', N'MEDIUM', N'HIGH', N'CRITICAL'))
);
GO

CREATE UNIQUE INDEX [IX_SensitiveName_LabelName] ON [DC].[SensitiveName] ([LabelName]);
