#!/usr/bin/env bash
# Runs the tests against a SQL Server 2019 or later: tests/run.sh <server> <user> <password>
# Needs sqlcmd, and git with the v1-article tag for the upgrade test. With sqlpackage on the
# PATH and the project built, it tests the dacpac as well. Creates and replaces the databases
# DdcTests, DdcUpgrade and DdcDacpac.
set -euo pipefail
cd "$(dirname "$0")/.."

server=$1
user=$2
password=$3

sql() { sqlcmd -S "$server" -U "$user" -P "$password" -C -b "$@"; }
fresh() {
    sql -d master -Q "IF DB_ID(N'$1') IS NOT NULL BEGIN ALTER DATABASE [$1] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$1]; END; CREATE DATABASE [$1];"
}

echo "== install/Install.sql"
fresh DdcTests
sql -d DdcTests -i install/Install.sql
if sql -d DdcTests -i install/Install.sql > /dev/null 2>&1; then
    echo "FAIL Install.sql ran over an existing DC schema"
    exit 1
fi
echo "ok   Install.sql refuses to run over an existing DC schema"
sql -d DdcTests -i tests/Tests.sql
sql -d DdcTests -i install/Uninstall.sql
sql -d DdcTests -i tests/AfterUninstall.sql

echo "== Upgrade from version 1"
fresh DdcUpgrade
v1=tests/v1-article.tmp.sql
trap 'rm -f "$v1"' EXIT
git show v1-article:DataDiscoveryAndClassification/AllInOne/CreateObjects.sql > "$v1"
sql -d DdcUpgrade -Q "CREATE TABLE dbo.Contact (ContactId INT NOT NULL PRIMARY KEY, FirstName NVARCHAR (50) NULL, Email NVARCHAR (100) NULL);"
sql -d DdcUpgrade -i "$v1" > /dev/null
sql -d DdcUpgrade -Q "EXECUTE DC.AcceptSuggestions;"
sql -d DdcUpgrade -i install/Uninstall.sql
sql -d DdcUpgrade -i install/Install.sql
sql -d DdcUpgrade -i tests/Upgrade.sql

dacpac=$(ls DataDiscoveryAndClassification/bin/*/DataDiscoveryAndClassification.dacpac 2> /dev/null | head -n 1 || true)
if command -v sqlpackage > /dev/null && [ -n "$dacpac" ]; then
    echo "== $dacpac"
    publish() {
        sqlpackage /Action:Publish /Quiet /SourceFile:"$dacpac" /TargetServerName:"$server" \
            /TargetDatabaseName:DdcDacpac /TargetUser:"$user" /TargetPassword:"$password" \
            /TargetTrustServerCertificate:True > /dev/null
    }
    fresh DdcDacpac
    publish
    sql -d DdcDacpac -i tests/Tests.sql
    publish
    sql -d DdcDacpac -Q "IF (SELECT COUNT(*) FROM DC.SensitiveName) <> 1 THROW 50001, N'FAIL deploying again replaced the imported policy', 1; PRINT N'ok   deploying again keeps the imported policy';"
else
    echo "== dacpac skipped (needs sqlpackage and a built project)"
fi
