CREATE TABLE [DC].[KeyWords](
	[KeywordName] [varchar](50) NOT NULL,
	[CanBeNumeric] [bit] NOT NULL,
	[InfoTypeId] [uniqueidentifier] NOT NULL,
	[ShouldLike] [bit] NOT NULL,
 CONSTRAINT [PK_KeyWords] PRIMARY KEY CLUSTERED 
(
	[KeywordName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
