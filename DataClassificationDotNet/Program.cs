using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using Microsoft.SqlServer.Management.Common;
using Microsoft.SqlServer.Management.Smo;

namespace DataClassificationDotNet
{
    static class Program
    {

        private const string SysTypesId = "sys_information_type_id";
        private const string SysTypesName = "sys_information_type_name";

        private const string SysLabelName = "sys_sensitivity_label_name";
        private const string SysLabelId = "sys_sensitivity_label_id";


        public static void Main()
        {
            string cDatabasename;
            ServerConnection cnn;
            var connectionString = ConfigurationManager.ConnectionStrings["ConnStr"].ConnectionString;

            var ds = new DataSet();

            using (var sqlConnection = new SqlConnection(connectionString))
            {

                cnn = new ServerConnection(sqlConnection);
                cDatabasename = cnn.DatabaseName;

                var custAdapter = new SqlDataAdapter(" SELECT * FROM DC.GetIntermediateResults;", sqlConnection);
                custAdapter.Fill(ds);
            }

            cnn.Connect();

            var interMediateResult = ds.Tables[0];
            //Create the server object
            var server = new Server(cnn);
            var db = server.Databases[cDatabasename];

            foreach (DataRow r in interMediateResult.Rows)
            {
                var tbl = db.Tables[r["TableName"].ToString(), r["SchemaName"].ToString()];
                var column = tbl.Columns[r["ColumnName"].ToString()];

                // Setup the first extended property SensitivityLabelId
                SetupExtProperty(column, SysLabelId, r["SensitivityLabelId"]);
                // Setup Label
                SetupExtProperty(column, SysLabelName, r["SensitivityLabelName"]);
                // Setup Information type id
                SetupExtProperty(column, SysTypesId, r["InformationTypeId"]);
                // Setup Information type 
                SetupExtProperty(column, SysTypesName, r["InformationTypeName"]);


                Console.WriteLine($"Processing {tbl.Schema}.{tbl.Name}.{column.Name}");
            }

            if (cnn.IsOpen)
                cnn.Disconnect();
            cnn = null;
            Console.WriteLine("Press any key to exit...");
            Console.ReadLine();

        }

        private static void SetupExtProperty(Column c, string propertyName, object value)
        {

            ExtendedProperty extProperty;

            if (c.ExtendedProperties[propertyName] == null)
            {
                extProperty = new ExtendedProperty
                {
                    Parent = c,
                    Name = propertyName,
                    Value = value
                };

                extProperty.Create();
            }
            else
            {
                extProperty = c.ExtendedProperties[propertyName];
                extProperty.Value = value;
                extProperty.Alter();
            }
        }

    }
}
