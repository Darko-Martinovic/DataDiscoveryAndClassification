CREATE TABLE [DC].[SensitiveName](
	[LabelId] [uniqueidentifier] NOT NULL,
	[LabelName] [varchar](30) NOT NULL,
	[LabelOrder] [int] NOT NULL,
 CONSTRAINT [PK__Sensitiv__397E2BC37BCB31E5] PRIMARY KEY CLUSTERED 
(
	[LabelId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

CREATE UNIQUE INDEX [IX_SensitiveName_LabelName] ON [DC].[SensitiveName] ([LabelName])

GO

CREATE INDEX [IX_SensitiveName_LabelOrder] ON [DC].[SensitiveName] ([LabelOrder])
