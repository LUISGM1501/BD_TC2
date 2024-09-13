#!/bin/bash

# Habilitar Always On Availability Groups
echo "Habilitando Always On Availability Groups..."
/opt/mssql/bin/mssql-conf set hadr.hadrenabled 1

# Esperar a que SQL Server esté listo para conexiones
echo "Esperando a que SQL Server esté listo para conexiones..."
sleep 30s

# Conectar a SQL Server y configurar el grupo de disponibilidad
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $MSSQL_SA_PASSWORD -Q "
-- Crear el endpoint de HADR
IF NOT EXISTS (SELECT * FROM sys.database_mirroring_endpoints WHERE name = 'Hadr_endpoint')
BEGIN
    CREATE ENDPOINT [Hadr_endpoint]
    STATE=STARTED
    AS TCP (LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES)
END

-- Crear el grupo de disponibilidad con failover manual
IF NOT EXISTS (SELECT * FROM sys.availability_groups WHERE name = 'AG_DB_TC2')
BEGIN
    CREATE AVAILABILITY GROUP [AG_DB_TC2]
    WITH (DB_FAILOVER = ON, AUTOMATED_BACKUP_PREFERENCE = SECONDARY)
    FOR DATABASE [DB_TC2_PrimaryDB]
    REPLICA ON N'$(hostname)' WITH (
        ENDPOINT_URL = 'TCP://$(hostname):5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        BACKUP_PRIORITY = 1,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = READ_ONLY)
    )
END
"
