<#
.SYNOPSIS
  Otimizacao geral e reversivel do Windows 11 para jogos.

.DESCRIPTION
  Sem parametros roda em SIMULACAO: mostra o que mudaria e nao altera nada.
    -Aplicar    aplica os ajustes e guarda backup do que existia antes
    -Reverter   desfaz os ajustes de registro, plano de energia e mouse
  Nao precisa de administrador. Nao remove nada do sistema.
  A limpeza de temporarios apaga so arquivos do SEU %TEMP% com mais de 7 dias
  e, por natureza, nao tem como ser revertida (ver README).

.EXAMPLE
  .\otimizar-windows-jogos.ps1
  .\otimizar-windows-jogos.ps1 -Aplicar
  .\otimizar-windows-jogos.ps1 -Reverter
#>
[CmdletBinding()]
param(
    [switch]$Aplicar,
    [switch]$Reverter,
    [int]$DiasTemp = 7,
    [switch]$SemLimpezaTemp
)

$ErrorActionPreference = 'Stop'
$pastaBackup = Join-Path $env:LOCALAPPDATA 'scripts-otimizacao'
$arquivoBackup = Join-Path $pastaBackup 'jogos-backup.json'
$simulacao = -not ($Aplicar -or $Reverter)

if ($Aplicar -and $Reverter) { Write-Error 'Use -Aplicar ou -Reverter, nao os dois.'; return }

function Info($t) { Write-Host $t }
function Acao($t) {
    if ($simulacao) { Write-Host "[simulacao] $t" -ForegroundColor Yellow } else { Write-Host "[ok] $t" -ForegroundColor Green }
}

function Ler-Reg($caminho, $nome) {
    $item = Get-Item -Path $caminho -ErrorAction SilentlyContinue
    if ($item -and ($item.GetValueNames() -contains $nome)) {
        return @{ existia = $true; valor = $item.GetValue($nome); tipo = [string]$item.GetValueKind($nome) }
    }
    return @{ existia = $false; valor = $null; tipo = $null }
}
function Gravar-Reg($caminho, $nome, $valor, $tipo) {
    if (-not (Test-Path $caminho)) { New-Item -Path $caminho -Force | Out-Null }
    New-ItemProperty -Path $caminho -Name $nome -Value $valor -PropertyType $tipo -Force | Out-Null
}
function Restaurar-Reg($e) {
    if ($e.existia) { Gravar-Reg $e.caminho $e.nome $e.valor $e.tipo }
    elseif (Test-Path $e.caminho) { Remove-ItemProperty -Path $e.caminho -Name $e.nome -ErrorAction SilentlyContinue }
}

# Aplica a aceleracao do mouse na hora (sem precisar sair da sessao)
Add-Type -Namespace Nativo -Name Mouse -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SystemParametersInfo(uint acao, uint parametro, int[] valores, uint flags);
'@
function Aplicar-Mouse([int]$limite1, [int]$limite2, [int]$aceleracao) {
    # SPI_SETMOUSE = 0x0004; 3 inteiros: limite1, limite2, aceleracao. flags 0 = so na sessao (o registro persiste)
    [Nativo.Mouse]::SystemParametersInfo(0x0004, 0, @($limite1, $limite2, $aceleracao), 0) | Out-Null
}

# ---------- REVERTER ----------
if ($Reverter) {
    if (-not (Test-Path $arquivoBackup)) { Write-Host "Nenhum backup em $arquivoBackup. Nada a reverter."; return }
    $b = Get-Content $arquivoBackup -Raw | ConvertFrom-Json
    foreach ($e in @($b.registro)) { Restaurar-Reg $e; Acao "Registro restaurado: $($e.caminho) [$($e.nome)]" }
    if ($b.mouse) {
        Aplicar-Mouse ([int]$b.mouse.limite1) ([int]$b.mouse.limite2) ([int]$b.mouse.aceleracao)
        Acao 'Aceleracao do mouse restaurada'
    }
    if ($b.planoEnergiaAnterior) { powercfg /setactive $b.planoEnergiaAnterior | Out-Null; Acao 'Plano de energia anterior reativado' }
    if ($b.planoCriadoPorNos) { powercfg /delete $b.planoCriadoPorNos 2>$null | Out-Null; Acao 'Plano de energia criado pelo script removido' }
    Remove-Item $arquivoBackup -Force
    Info 'Revertido. (Temporarios apagados nao voltam; eram arquivos descartaveis.)'
    return
}

if ($simulacao) { Info '=== SIMULACAO: nada sera alterado. Use -Aplicar para aplicar. ===' }
if (-not $simulacao -and (Test-Path $arquivoBackup)) {
    Write-Error "Ja existe um backup em $arquivoBackup (ajustes ja aplicados). Rode -Reverter antes de aplicar de novo."
    return
}

$backup = @{ registro = @(); mouse = $null; planoEnergiaAnterior = $null; planoCriadoPorNos = $null }

function Ajustar-Reg($caminho, $nome, $valor, $tipo, $descricao) {
    $antes = Ler-Reg $caminho $nome
    if ($antes.existia -and "$($antes.valor)" -eq "$valor") { Info "Ja estava assim: $descricao"; return }
    Acao $descricao
    if (-not $simulacao) {
        $script:backup.registro += @{ caminho = $caminho; nome = $nome; existia = $antes.existia; valor = $antes.valor; tipo = $antes.tipo }
        Gravar-Reg $caminho $nome $valor $tipo
    }
}

# 1. Modo de Jogo
Ajustar-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 'DWord' 'Modo de Jogo ligado'
Ajustar-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 'DWord' 'Modo de Jogo automatico permitido'

# 2. Captura do Game Bar / Game DVR
Ajustar-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'DWord' 'Game DVR desligado'
Ajustar-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'DWord' 'Captura em segundo plano desligada'
Ajustar-Reg 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0 'DWord' 'Game Bar nao abre pelo botao do controle'

# 3. Plano de energia
$ativo = (powercfg /getactivescheme) -replace '.*:\s*([0-9a-fA-F-]{36}).*', '$1'
$altoDesempenho = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
if ($ativo -eq $altoDesempenho) {
    Info 'Plano de energia ja e Alto desempenho.'
} else {
    Acao "Plano de energia: $ativo -> Alto desempenho"
    if (-not $simulacao) {
        $backup.planoEnergiaAnterior = $ativo
        if ((powercfg /list) -match $altoDesempenho) {
            powercfg /setactive $altoDesempenho | Out-Null
        } else {
            $novo = (powercfg /duplicatescheme $altoDesempenho) -replace '.*:\s*([0-9a-fA-F-]{36}).*', '$1'
            $backup.planoCriadoPorNos = $novo
            powercfg /setactive $novo | Out-Null
        }
    }
}

# 4. Aceleracao do mouse ("Aprimorar precisao do ponteiro")
$m = Get-ItemProperty 'HKCU:\Control Panel\Mouse'
if ($m.MouseSpeed -eq '0' -and $m.MouseThreshold1 -eq '0' -and $m.MouseThreshold2 -eq '0') {
    Info 'Aceleracao do mouse ja esta desligada.'
} else {
    Acao 'Aceleracao do mouse desligada (movimento 1:1)'
    if (-not $simulacao) {
        $backup.mouse = @{ limite1 = [int]$m.MouseThreshold1; limite2 = [int]$m.MouseThreshold2; aceleracao = [int]$m.MouseSpeed }
        $backup.registro += @{ caminho = 'HKCU:\Control Panel\Mouse'; nome = 'MouseSpeed'; existia = $true; valor = $m.MouseSpeed; tipo = 'String' }
        $backup.registro += @{ caminho = 'HKCU:\Control Panel\Mouse'; nome = 'MouseThreshold1'; existia = $true; valor = $m.MouseThreshold1; tipo = 'String' }
        $backup.registro += @{ caminho = 'HKCU:\Control Panel\Mouse'; nome = 'MouseThreshold2'; existia = $true; valor = $m.MouseThreshold2; tipo = 'String' }
        Gravar-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
        Gravar-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
        Gravar-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
        Aplicar-Mouse 0 0 0
    }
}

# 5. Limpeza de temporarios do usuario (so %TEMP%, so arquivos com mais de N dias)
if (-not $SemLimpezaTemp) {
    $limite = (Get-Date).AddDays(-$DiasTemp)
    $velhos = Get-ChildItem -LiteralPath $env:TEMP -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $limite }
    $total = ($velhos | Measure-Object Length -Sum).Sum
    $mb = [math]::Round(($(if ($total) { $total } else { 0 })) / 1MB, 1)
    Acao "Temporarios com mais de $DiasTemp dias em $env:TEMP : $(@($velhos).Count) arquivos, $mb MB"
    if (-not $simulacao) {
        $apagados = 0
        foreach ($f in $velhos) {
            try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $apagados++ } catch { }  # em uso: ignora
        }
        Info "  $apagados arquivos apagados (os em uso foram ignorados)."
    }
}

# ---------- Relatorios (somente leitura) ----------
Write-Host "`n--- Programas de inicializacao ---" -ForegroundColor Cyan
Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
    Sort-Object Name | Format-Table Name, Location, Command -AutoSize -Wrap | Out-String -Width 200 | Write-Host
Info 'Para desativar algum: Configuracoes > Aplicativos > Inicializacao (este script nao mexe nisso).'

Write-Host "--- 10 processos que mais usam RAM ---" -ForegroundColor Cyan
Get-Process | Group-Object ProcessName |
    ForEach-Object { [pscustomobject]@{ Processo = $_.Name; Instancias = $_.Count; 'RAM (MB)' = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB) } } |
    Sort-Object 'RAM (MB)' -Descending | Select-Object -First 10 | Format-Table -AutoSize | Out-String | Write-Host

if (-not $simulacao) {
    New-Item -ItemType Directory -Path $pastaBackup -Force | Out-Null
    $backup | ConvertTo-Json -Depth 5 | Set-Content -Path $arquivoBackup -Encoding UTF8
    Info "Backup salvo em $arquivoBackup. Para desfazer: .\otimizar-windows-jogos.ps1 -Reverter"
}
