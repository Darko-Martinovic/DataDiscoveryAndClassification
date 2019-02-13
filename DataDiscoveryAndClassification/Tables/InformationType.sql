CREATE TABLE [DC].[InformationType](
	[InfoTypeId] [uniqueidentifier] NOT NULL,
	[InfoTypeName] [varchar](30) NOT NULL,
	[InfoTypeOrder] [int] NOT NULL,
	[RecommendedLabelId] [uniqueidentifier] NULL,
 CONSTRAINT [PK__Informat__E94AB524B904E7BD] PRIMARY KEY CLUSTERED 
(
	[InfoTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

CREATE UNIQUE INDEX [IX_InformationType_Name] ON [DC].[InformationType] ([InfoTypeName])

GO

CREATE UNIQUE INDEX [IX_InformationType_Order] ON [DC].[InformationType] ([InfoTypeOrder])
