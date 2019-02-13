ALTER TABLE [DC].[InformationType]  WITH CHECK ADD  CONSTRAINT [FK_InformationType_SensitiveName] FOREIGN KEY([RecommendedLabelId])
REFERENCES [DC].[SensitiveName] ([LabelId])
