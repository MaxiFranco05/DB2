<#
.SYNOPSIS
    Script automatizado de respaldo para la base de datos Food Store (PostgreSQL 16+).
.DESCRIPTION
    Genera un respaldo en formato binario comprimido (-Fc), registra metricas en carpeta logs/
    y finaliza con error (exit 1) si pg_dump falla.
    Cumple con las directivas de seguridad de SPEC_U6.md (sin contrasenas expuestas).
.PARAMETER DbHost
    Host de conexion a PostgreSQL (por defecto: localhost).
.PARAMETER DbPort
    Puerto de escucha del motor (por defecto: 5432).
.PARAMETER DbUser
    Usuario de PostgreSQL (por defecto: postgres).
.PARAMETER DbName
    Nombre de la base de datos a respaldar (por defecto: foodstore).
#>
[CmdletBinding()]
param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbUser = "postgres",
    [string]$DbName = "foodstore"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$backupsDir = Join-Path $scriptDir "backups"
$logsDir = Join-Path $scriptDir "logs"

# Asegurar existencia de directorios requeridos
if (-not (Test-Path $backupsDir)) {
    New-Item -Path $backupsDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $logsDir)) {
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dumpFileName = "${DbName}_${timestamp}.dump"
$dumpFilePath = Join-Path $backupsDir $dumpFileName
$logFileName = "backup_${timestamp}.log"
$logFilePath = Join-Path $logsDir $logFileName

$inicio = Get-Date
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Write-Log {
    param([string]$Message)
    $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$time] $Message"
    Write-Output $line
    Add-Content -Path $logFilePath -Value $line -Encoding UTF8
}

Write-Log "=========================================================="
Write-Log "INICIO DE RESPALDO: $DbName"
Write-Log "Host: $DbHost | Puerto: $DbPort | Usuario: $DbUser"
Write-Log "Destino Dump: $dumpFilePath"
Write-Log "=========================================================="

# Ejecucion de pg_dump en formato custom (-Fc)
# NOTA DE SEGURIDAD: La autenticacion se resuelve mediante variable de entorno efimera
# $env:PGPASSWORD o archivo seguro pgpass.conf. Jamas se expone en argumentos de linea de comandos.
$pgDumpCmd = "pg_dump -h $DbHost -p $DbPort -U $DbUser -d $DbName -Fc -f `"$dumpFilePath`""
Write-Log "Ejecutando comando: $pgDumpCmd"

& pg_dump -h $DbHost -p $DbPort -U $DbUser -d $DbName -Fc -f "$dumpFilePath" 2>&1 | ForEach-Object {
    Write-Log "[pg_dump]: $_"
}

# REGLA CRITICA: Capturar $LASTEXITCODE inmediatamente sin comandos intermedios
$dumpExitCode = $LASTEXITCODE

$stopwatch.Stop()
$fin = Get-Date
$duracionSeg = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

Write-Log "----------------------------------------------------------"
Write-Log "Codigo de salida retornado por pg_dump: $dumpExitCode"
Write-Log "Duracion total de ejecucion: $duracionSeg segundos"

if ($dumpExitCode -ne 0 -or -not (Test-Path $dumpFilePath)) {
    Write-Log "[ERROR CRITICO] El respaldo fallo con codigo $dumpExitCode o el archivo no fue generado."
    Write-Log "=========================================================="
    exit 1
}

$dumpSize = (Get-Item $dumpFilePath).Length
$dumpSizeMB = [math]::Round($dumpSize / 1MB, 2)

if ($dumpSize -le 0) {
    Write-Log "[ERROR CRITICO] El archivo generado tiene tamano 0 bytes."
    Write-Log "=========================================================="
    exit 1
}

Write-Log "Tamano final del respaldo: $dumpSize bytes ($dumpSizeMB MB)"
Write-Log "[EXITO] Respaldo finalizado correctamente y validado."
Write-Log "=========================================================="
exit 0
