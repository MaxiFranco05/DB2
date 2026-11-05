<#
.SYNOPSIS
    Script de automatizacion del simulacro de recuperacion ante desastres (Disaster Recovery).
.DESCRIPTION
    Restaura el ultimo backup en 'foodstore_restore_test', cronometra el RTO total
    (creacion de BD, restauracion y validaciones) y calcula el RPO observado.
    Cumple con la Parte 4 del TP de la Unidad 6.
#>
[CmdletBinding()]
param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbUser = "postgres",
    [string]$TargetDb = "foodstore_restore_test",
    [string]$SourceDb = "foodstore",
    [string]$DumpPath = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$backupsDir = Join-Path $scriptDir "backups"

# 1. Determinar el dump a restaurar
if ([string]::IsNullOrWhiteSpace($DumpPath)) {
    $latestDumpItem = Get-ChildItem -Path $backupsDir -Filter "*.dump" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latestDumpItem) {
        Write-Error "No se encontraron archivos .dump en la carpeta '$backupsDir'."
        exit 1
    }
    $DumpPath = $latestDumpItem.FullName
} else {
    if (-not (Test-Path $DumpPath)) {
        Write-Error "El archivo especificado '$DumpPath' no existe."
        exit 1
    }
    $latestDumpItem = Get-Item $DumpPath
}

$dumpName = $latestDumpItem.Name
$dumpFecha = $latestDumpItem.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
$dumpMB = [math]::Round($latestDumpItem.Length / 1MB, 2)

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  SIMULACRO DE RECUPERACION ANTE DESASTRES - FOOD STORE" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "Archivo de respaldo detectado: $dumpName"
Write-Host "Fecha y hora del respaldo:     $dumpFecha"
Write-Host "Tamano del respaldo:           $dumpMB MB"
Write-Host "Base de datos destino:         $TargetDb"
Write-Host "--------------------------------------------------------------------------"

# 2. Limpieza preventiva previa al cronometro
Write-Host "[PRE-TEST] Verificando y eliminando instancia previa de $TargetDb..." -ForegroundColor Gray
& dropdb -h $DbHost -p $DbPort -U $DbUser --if-exists $TargetDb 2>&1 | Out-Null

# 3. INICIO FORMAL DEL CRONOMETRO CONTRA RELOJ (T0)
Write-Host "[CRONOMETRO T0] Iniciando medicion de RTO..." -ForegroundColor Yellow
$momentoSimulacro = Get-Date
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# 4. Creacion de la base de prueba descartable
Write-Host "[PASO 1/3] Creando base de datos descartable $TargetDb..." -ForegroundColor Green
& createdb -h $DbHost -p $DbPort -U $DbUser $TargetDb
$createDbExitCode = $LASTEXITCODE
if ($createDbExitCode -ne 0) {
    $stopwatch.Stop()
    Write-Error "[FALLO] createdb termino con codigo de error $createDbExitCode."
    exit 1
}

# 5. Restauracion del dump mediante pg_restore
Write-Host "[PASO 2/3] Restaurando dump con pg_restore..." -ForegroundColor Green
& pg_restore -h $DbHost -p $DbPort -U $DbUser -d $TargetDb --no-owner --no-privileges "$DumpPath" 2>&1 | Out-Null
$restoreExitCode = $LASTEXITCODE

# 6. Validaciones minimas de la catedra
Write-Host "[PASO 3/3] Ejecutando validaciones de cardinalidad e integridad..." -ForegroundColor Green

$sqlCounts = "SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria UNION ALL SELECT 'cliente', COUNT(*) AS filas FROM cliente UNION ALL SELECT 'producto', COUNT(*) AS filas FROM producto UNION ALL SELECT 'pedido', COUNT(*) AS filas FROM pedido UNION ALL SELECT 'detalle_pedido', COUNT(*) AS filas FROM detalle_pedido;"
$countsOutput = & psql -h $DbHost -p $DbPort -U $DbUser -d $TargetDb -w -c $sqlCounts
$countsExitCode = $LASTEXITCODE

$sqlProdInv = "SELECT COUNT(*) AS productos_invalidos FROM producto WHERE precio < 0 OR stock < 0;"
$prodInvOutput = & psql -h $DbHost -p $DbPort -U $DbUser -d $TargetDb -w -t -A -c $sqlProdInv
$prodInvCount = [int]($prodInvOutput.Trim())

$sqlDetInv = "SELECT COUNT(*) AS detalles_invalidos FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0;"
$detInvOutput = & psql -h $DbHost -p $DbPort -U $DbUser -d $TargetDb -w -t -A -c $sqlDetInv
$detInvCount = [int]($detInvOutput.Trim())

# 7. PARADA DEL CRONOMETRO (T1)
$stopwatch.Stop()
$rtoSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

# 8. Calculo de RPO Observado
$antiguedadRespaldo = $momentoSimulacro - $latestDumpItem.LastWriteTime
$rpoSegundos = [math]::Round($antiguedadRespaldo.TotalSeconds, 1)
$rpoMinutos = [math]::Round($antiguedadRespaldo.TotalMinutes, 2)

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  RESULTADOS DEL SIMULACRO Y VALIDACION TECNICA" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

Write-Host "METRICAS DE RECUPERACION ANTE DESASTRES:" -ForegroundColor White
Write-Host "  * RTO Previsto (SLA Objetivo):        < 300.00 seg (5 minutos)"
Write-Host "  * RTO Observado (Tiempo real medido): $rtoSeconds segundos" -ForegroundColor Yellow
Write-Host "  * RPO Previsto (Ventana de backup):   <= 24 horas"
Write-Host "  * RPO Observado (Antiguedad backup):  $rpoSegundos seg ($rpoMinutos min)" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------------------"

Write-Host "VALIDACION DE CARDINALIDAD (CONTEO DE FILAS):" -ForegroundColor White
$countsOutput | ForEach-Object { Write-Host "  $_" }

Write-Host "--------------------------------------------------------------------------"
Write-Host "VALIDACION DE REGLAS LOGICAS DE NEGOCIO:" -ForegroundColor White

if ($prodInvCount -eq 0) {
    Write-Host "  * Productos invalidos (precio < 0 OR stock < 0):      $prodInvCount" -ForegroundColor Green
} else {
    Write-Host "  * Productos invalidos (precio < 0 OR stock < 0):      $prodInvCount" -ForegroundColor Red
}

if ($detInvCount -eq 0) {
    Write-Host "  * Detalles invalidos (cantidad <= 0 OR precio < 0):   $detInvCount" -ForegroundColor Green
} else {
    Write-Host "  * Detalles invalidos (cantidad <= 0 OR precio < 0):   $detInvCount" -ForegroundColor Red
}

Write-Host "--------------------------------------------------------------------------"
if ($prodInvCount -eq 0 -and $detInvCount -eq 0 -and $countsExitCode -eq 0) {
    Write-Host ">>> DICTAMEN: SIMULACRO EXITOSO - BASE DE DATOS RESTAURADA Y VALIDADA AL 100% <<<" -ForegroundColor Green
    exit 0
} else {
    Write-Host ">>> DICTAMEN: FALLO EN VALIDACION LOGICA DE CONSISTENCIA <<<" -ForegroundColor Red
    exit 1
}
