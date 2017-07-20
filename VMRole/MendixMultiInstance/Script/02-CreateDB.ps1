param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ServerName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $SqlUserName = 'sa',

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SqlPassword,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Database
)

$Password = 'Demo1234!'

function Invoke-SQL {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ServerName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $SqlUserName = 'sa',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SqlPassword,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Query,

        [Parameter()]
        [ValidateSet('Table', 'Value', 'None')]
        [string] $ReturnType = 'Table'
    )

    if ($ServerName.Split(':').Count -gt 1) {
        $ServerName, $port = $ServerName.Split(':')
    } else {
        $port = 1433
    }

    $connectionString = "Server=$ServerName,$port;user id=$SqlUserName;password=$SqlPassword;trusted_Connection=False;"

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString
        $null = $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $query

        switch ($ReturnType) {
            Table {
                $results = $command.ExecuteReader()

                $returnArray = New-Object -TypeName System.Collections.ArrayList

                foreach ($result in $results) {
                    $table = @{}
                    for ($i = 0; $i -lt $result.FieldCount; $i++) {
                        $null = $table.Add($result.getname($i), $result[$i])
                    }
                    $null = $returnArray.Add($table)
                }
                $returnArray

            }
            Value {
                $command.ExecuteScalar()
            }

            None {
                $null = $command.ExecuteNonQuery()
            }
        }
    }
    catch {
        Write-Error -ErrorRecord $_ -ErrorAction Stop
    }
    finally {
        if ($connection) {
            $connection.Close()
            $connection.Dispose()
        }
    }
}

$testQuery = @'
        select name
        FROM master.dbo.sysdatabases 
        where name = '{0}'
'@ -f $Database

if (Test-Path -Path c:\VMRole\First) {
    if ($null -eq (Invoke-SQL -ServerName $ServerName -SqlUserName $SqlUserName -SqlPassword $SqlPassword -Query $testQuery -ReturnType Value)) {
        $createQuery = @'
            CREATE DATABASE [{0}]
                CONTAINMENT = NONE
'@ -f $Database

        Invoke-SQL -ServerName $ServerName -SqlUserName $SqlUserName -SqlPassword $SqlPassword -Query $createQuery -ReturnType None

        $loginQuery = @'
            If not Exists (select loginname from master.dbo.syslogins 
                where name = '{0}')
            Begin
                CREATE LOGIN [{0}] WITH PASSWORD=N'{1}', DEFAULT_DATABASE=[{0}], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
            End   
            USE [{0}]
            CREATE USER [{0}] FOR LOGIN [{0}]
            ALTER ROLE [db_owner] ADD MEMBER [{0}]
            USE [master]
            exec sp_addsrvrolemember @loginame = '{0}', @rolename = 'sysadmin'
'@ -f $Database, $Password

        Invoke-SQL -ServerName $ServerName -SqlUserName $SqlUserName -SqlPassword $SqlPassword -Query $loginQuery -ReturnType None
    }
    else {
        Write-Error -Message "Database with name $Database already exists on server $ServerName" -ErrorAction Stop
    }
}
else {
    if ($null -eq (Invoke-SQL -ServerName $ServerName -SqlUserName $SqlUserName -SqlPassword $SqlPassword -Query $testQuery -ReturnType Value)) {
        Write-Error -Message "Database with name $Database dos not exist on server $ServerName" -ErrorAction Stop
    }
}
