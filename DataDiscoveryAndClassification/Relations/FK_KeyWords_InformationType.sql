ALTER TABLE [DC].[KeyWords]  WITH CHECK ADD  CONSTRAINT [FK_KeyWords_InformationType] FOREIGN KEY([InfoTypeId])
REFERENCES [DC].[InformationType] ([InfoTypeId])
GO
