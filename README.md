# Data Discovery & Classification in T-SQL

[![build](https://github.com/Darko-Martinovic/DataDiscoveryAndClassification/actions/workflows/build.yml/badge.svg)](https://github.com/Darko-Martinovic/DataDiscoveryAndClassification/actions/workflows/build.yml)

SQL Server Management Studio (SSMS) can scan a database, suggest which columns hold sensitive data, and label them with a sensitivity classification. This project does the same thing in plain T-SQL, inside the database:

- it finds columns whose names match the keyword patterns of an Information Protection policy (Microsoft's default policy, or your own);
- it suggests an information type, a sensitivity label and a rank for each of them;
- it applies the suggestions with `ADD SENSITIVITY CLASSIFICATION`, so they show up in SSMS, in `sys.sensitivity_classifications` and in [SQL Server Audit](https://learn.microsoft.com/sql/relational-databases/security/sql-data-discovery-and-classification).

Because it is only T-SQL, you can classify databases from a deployment pipeline, a SQL Agent job or a `sqlcmd` script, without SSMS or PowerShell. You also review and change the keywords in tables, and query the suggestions like any other view.

## Contents

- [When to use it](#when-to-use-it)
- [Requirements](#requirements)
- [Install](#install)
- [Classify a database](#classify-a-database)
- [Use your own policy](#use-your-own-policy)
- [Classifications from SQL Server 2017 and earlier](#classifications-from-sql-server-2017-and-earlier)
- [Remove classifications or the project](#remove-classifications-or-the-project)
- [What is in the DC schema](#what-is-in-the-dc-schema)
- [Develop and test](#develop-and-test)
- [Version 1 and the article](#version-1-and-the-article)
- [License](#license)

## When to use it

| You want to | Use |
|---|---|
| Classify one database by hand, with a UI | SSMS: **Tasks > Data Discovery and Classification > Classify Data** |
| Use Microsoft Purview (Microsoft 365) sensitivity labels | SSMS in Microsoft Information Protection policy mode. SSMS makes no suggestions in that mode |
| Classify from PowerShell | The SqlServer module's `Get-SqlSensitivityRecommendations` and `Set-SqlSensitivityClassification` |
| Classify from T-SQL, review suggestions with a query, keep the keywords in tables, or move classifications kept in extended properties to SQL Server 2019 or later | This project |

This project and SSMS read the same policy file format, so you can keep a single policy for both.

## Requirements

- SQL Server 2019 or later. CI tests every change on SQL Server 2019, 2022 and 2025 (Linux containers). Azure SQL Database and Azure SQL Managed Instance support the same statements, but they aren't tested.
- Database compatibility level 130 or higher, because the policy is read with `OPENJSON`.
- To install: permission to create a schema, tables, views, functions and procedures in the database.
- To classify: `ALTER ANY SENSITIVITY CLASSIFICATION`, which the `ALTER` permission on the database includes. To read classifications: `VIEW ANY SENSITIVITY CLASSIFICATION`.

For SQL Server 2017 and earlier, which keep classifications in extended properties, use [version 1](#version-1-and-the-article).

## Install

Pick one of two ways. Both create the `DC` schema in the database you choose and load [Microsoft's default policy](policy/sql_information_protection_default.json): 6 labels, 12 information types and 361 keywords in several languages.

**With a script.** Run [install/Install.sql](install/Install.sql) in the database, from SSMS or with `sqlcmd`:

```shell
sqlcmd -S <server> -d <database> -E -i install/Install.sql
```

The script stops if the server is older than SQL Server 2019, if the compatibility level is below 130, or if the `DC` schema already exists.

**As a database project.** [DataDiscoveryAndClassification](DataDiscoveryAndClassification) is an SDK-style SQL project ([Microsoft.Build.Sql](https://learn.microsoft.com/sql/tools/sql-database-projects/sql-database-projects)). Build it with the .NET SDK and publish the dacpac with [SqlPackage](https://learn.microsoft.com/sql/tools/sqlpackage/sqlpackage), or open it in Visual Studio or VS Code:

```shell
dotnet build DataDiscoveryAndClassification
sqlpackage /Action:Publish /SourceFile:DataDiscoveryAndClassification/bin/Debug/DataDiscoveryAndClassification.dacpac /TargetConnectionString:"Server=<server>;Database=<database>;Integrated Security=true;TrustServerCertificate=true"
```

Publishing again later updates the objects. It loads the default policy only when the label table is empty, so any policy you imported stays.

## Classify a database

Say the database has this table:

```sql
CREATE TABLE Sales.Customer
(
    CustomerId       INT            NOT NULL PRIMARY KEY,
    FirstName        NVARCHAR (50)  NOT NULL,
    Email            NVARCHAR (100) NULL,
    AddressId        INT            NULL,
    CreditCardNumber VARCHAR (20)   NULL,
    DOB              DATE           NULL
);
```

1. Review the suggestions:

   ```sql
   SELECT SchemaName, TableName, ColumnName, InformationTypeName, SensitivityLabelName, SensitivityRank
   FROM DC.GetIntermediateResults;
   ```

   | SchemaName | TableName | ColumnName | InformationTypeName | SensitivityLabelName | SensitivityRank |
   |---|---|---|---|---|---|
   | Sales | Customer | CreditCardNumber | Credit Card | Confidential | MEDIUM |
   | Sales | Customer | DOB | Date Of Birth | Confidential - GDPR | MEDIUM |
   | Sales | Customer | Email | Contact Info | Confidential | MEDIUM |
   | Sales | Customer | FirstName | Name | Confidential - GDPR | MEDIUM |

   `AddressId` matches the keyword `%addr%`, but that keyword can't be numeric, so an `INT` column is left out.

2. Accept them. Either every suggestion is applied, or none is:

   ```sql
   EXECUTE DC.AcceptSuggestions;
   ```

   To leave a column out, classify it yourself before accepting (columns that are classified already never get suggestions). You can also change the keywords first (see below).

3. See every classified column, whether this project, SSMS or anyone else added it:

   ```sql
   SELECT * FROM DC.GetClassifiedColumns;
   ```

How a column gets its suggestion:

- Its name is compared with every keyword. A keyword is a `LIKE` pattern, such as `%email%` or `%[^h]ip%address%`, and the comparison ignores case.
- Some columns are left out: those in the `DC` schema, `bit` columns, and columns whose numeric type rules out a keyword marked "can't be numeric". Computed columns and history tables are left out as well, because SQL Server won't classify them. A history table gets the classification of its current table.
- When a column matches keywords of more than one information type, the type with the lowest order wins. For example, `AccountPassword` is Credentials (order 300), not Financial (`%account%`, order 900).
- The label is the one the information type recommends, and the rank is the label's rank.

## Use your own policy

The policy lives in three tables: `DC.SensitiveName` (labels and their ranks), `DC.InformationType` (types and their recommended labels) and `DC.KeyWords` (patterns). You can edit them directly. You can also load a whole policy file with `DC.ImportPolicy`, which replaces the tables' contents. The file is the JSON that SSMS exports with **Tasks > Data Discovery and Classification > Export Information Protection Policy**, in the same format as [Microsoft's default](policy/sql_information_protection_default.json).

```sql
-- The file must be on a disk the SQL Server service can read.
-- The UTF-8 collation makes SQL Server read the file's bytes as UTF-8.
DECLARE @file TABLE (Policy VARCHAR (MAX) COLLATE Latin1_General_100_CI_AS_SC_UTF8);
INSERT INTO @file (Policy)
SELECT BulkColumn FROM OPENROWSET(BULK N'C:\Policies\policy.json', SINGLE_BLOB) AS PolicyFile;

DECLARE @policy AS NVARCHAR (MAX) = (SELECT Policy FROM @file);
EXECUTE DC.ImportPolicy @Policy = @policy;
```

When it imports a file, `DC.ImportPolicy`:

- leaves out disabled labels, disabled information types and excluded keywords;
- leaves an information type without a label if the label it recommends is disabled;
- doesn't touch the classifications already on columns.

To go back to Microsoft's default policy, run the `EXECUTE DC.ImportPolicy` statement in [PostDeploy/Seed.sql](DataDiscoveryAndClassification/PostDeploy/Seed.sql).

## Classifications from SQL Server 2017 and earlier

Before SQL Server 2019, SSMS (and version 1 of this project) stored classifications as four extended properties on each column: `sys_information_type_name`, `sys_information_type_id`, `sys_sensitivity_label_name` and `sys_sensitivity_label_id`. After a database is upgraded, SQL Server still has these properties, but `sys.sensitivity_classifications` and auditing ignore them.

```sql
SELECT * FROM DC.GetLegacyClassifiedColumns;             -- what is there
EXECUTE DC.MigrateLegacyClassification;                  -- copy it into sys.sensitivity_classifications
EXECUTE DC.MigrateLegacyClassification @DropLegacy = 1;  -- copy it, then drop the extended properties
```

`DC.MigrateLegacyClassification` doesn't change a column that is already classified in `sys.sensitivity_classifications`. It takes the rank from `DC.SensitiveName` when the label is there.

## Remove classifications or the project

```sql
EXECUTE DC.RemoveClassification;  -- removes EVERY column classification in the database, not only this project's
```

[install/Uninstall.sql](install/Uninstall.sql) drops the `DC` schema and its objects, from version 1 or version 2, but keeps the classifications.

## What is in the DC schema

| Object | What it does |
|---|---|
| `DC.SensitiveName` | Sensitivity labels, with their order and rank (`NONE`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`) |
| `DC.InformationType` | Information types, with their order and recommended label |
| `DC.KeyWords` | Column-name patterns for each information type, and whether a numeric column may match |
| `DC.GetMatchingColumns` | Every user-table column that matches a keyword |
| `DC.GetIntermediateResults` | The suggestions: one type, label and rank for each unclassified matching column |
| `DC.GetClassifiedColumns` | Every classified column, from `sys.sensitivity_classifications` |
| `DC.GetLegacyClassifiedColumns` | Columns classified in extended properties |
| `DC.AcceptSuggestions` | Applies every suggestion, in one transaction |
| `DC.RemoveClassification` | Removes every column classification, in one transaction |
| `DC.MigrateLegacyClassification` | Copies extended-property classifications into `sys.sensitivity_classifications`; `@DropLegacy = 1` drops the properties afterwards |
| `DC.ImportPolicy` | Replaces the labels, types and keywords with those of a policy file |
| `DC.AddClassificationStatement` | Builds one `ADD SENSITIVITY CLASSIFICATION` statement, with names quoted and values escaped |

## Develop and test

```text
DataDiscoveryAndClassification/   the SQL project: one file per object, PostDeploy/Seed.sql loads the policy
policy/                           Microsoft's default Information Protection policy
install/                          Install.sql (generated) and Uninstall.sql
tools/Build-Scripts.ps1           writes Seed.sql from the policy and Install.sql from the project
tests/                            T-SQL tests and tests/run.sh, which runs them with sqlcmd
```

After you change an object or the policy, run `pwsh tools/Build-Scripts.ps1` and commit the regenerated scripts. CI fails if they are out of date.

`tests/run.sh` needs `sqlcmd`, and git with the `v1-article` tag. It runs three suites, each in a new database (`DdcTests`, `DdcUpgrade`, `DdcDacpac`):

- the tests against `Install.sql`, then `Uninstall.sql`;
- an upgrade from version 1, which installs version 1, classifies with it, then installs version 2 and migrates;
- if `sqlpackage` is on the PATH and the project is built, the tests against the published dacpac.

To run it against a SQL Server in a container:

```shell
docker run -d --name ddc -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='<a strong password>' -p 1433:1433 mcr.microsoft.com/mssql/server:2025-latest
dotnet build DataDiscoveryAndClassification
tests/run.sh localhost sa '<a strong password>'
```

## Version 1 and the article

The article [Data Discovery & Classification in SQL Server](https://www.linkedin.com/pulse/data-discovery-classification-sql-server-darko-martinovic/) (2019) describes version 1. That version is tagged [`v1-article`](https://github.com/Darko-Martinovic/DataDiscoveryAndClassification/tree/v1-article). It was a Visual Studio 2017 database project plus a .NET Framework console app, and it targeted SQL Server 2012 to 2019.

Version 2 keeps the idea and the main names (`DC.GetMatchingColumns`, `DC.GetIntermediateResults`, `DC.GetClassifiedColumns`, `DC.AcceptSuggestions`, `DC.RemoveClassification`), and changes the rest:

- **Where classifications go.** It writes them to `sys.sensitivity_classifications` (SQL Server 2019 and later) and adds a rank. Version 1 wrote extended properties, and copied them to SQL Server 2019 only on request.
- **Fixes.**
  - The SQL Server 2019 procedures checked for version `15` exactly, so they did nothing on SQL Server 2022 and 2025.
  - The generated statements didn't quote names or escape values, so a name with a space or a bracket, or a label with an apostrophe, broke them.
  - `RemoveClassification` failed on a column that had only some of the four extended properties.
- **The policy.** The keywords come from Microsoft's policy file through `DC.ImportPolicy`. In version 1 they were typed into an insert script. That script lost the 7 keywords with an apostrophe in them, and it cut `%codigo%` down to `%codi%` in 6 more.
- **New:** `DC.ImportPolicy`, `DC.MigrateLegacyClassification`, `DC.GetLegacyClassifiedColumns`, `Install.sql` and `Uninstall.sql`, the tests and CI.
- **Removed:**
  - The console app, which did the same job as `DC.AcceptSuggestions`.
  - The Excel copy of the keywords.
  - `DC.AddSensitivityClassification` and `DC.DropSensitivityClassification`. `DC.MigrateLegacyClassification` and `DC.RemoveClassification` replace them.

## License

[MIT](LICENSE). [policy/sql_information_protection_default.json](policy/sql_information_protection_default.json) is Microsoft's default policy, from [Azure-Samples/sql-data-classification](https://github.com/Azure-Samples/sql-data-classification) (MIT).
