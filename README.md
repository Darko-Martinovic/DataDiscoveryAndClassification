## :white_check_mark: DataDiscoveryAndClassification


Visual Studio 2017 Database Project that extends Microsoft solution for Data Classification


Table Name                                       | Description
-------------------------------------------------|---------------------------------------------------------------------------------
[DC].[SensitiveName]                             | Contains the list of sensitivity level of the data stored in the column. 
[DC].[InformationType]                           | Provide additional granularity into the type of data stored in the column.
[DC].[KeyWords]                                  | Contains the list of keyword patterns needed to apply sensitivity attribute to the column

View Name                                        | Description
------------------------------------------------ |-----------------------------------------------------------------------------------
[DC].[GetMatchingColumns]                        | Joins sys.tables with DC.KeyWords in order to produce the first intermediate result.
[DC].[GetInterMeddiateResult]                    | Cleans up the matching columns and apply additional attributes.
[DC].[GetClassifiedColumns]                      | Get a list of columns that are considered to be sensitive. 

Stored Procedure Name                            | Description
------------------------------------------------ |-----------------------------------------------------------------------------------
[DC].[Accept Suggestion]                         | Joins sys.tables with DC.KeyWords in order to produce the first intermediate result.
[DC].[GetInterMeddiateResult]                    | Cleans up the matching columns and apply additional attributes.
DC.GetClassifiedColumns                          | Get a list of columns that are considered to be sensitive. 

