<#
.SYNOPSIS
  Ajustes seguros e reversiveis para jogar Counter-Strike 2 no Windows 11.

.DESCRIPTION
  Sem parametros roda em SIMULACAO: mostra o que mudaria e nao altera nada.
    -Aplicar    aplica os ajustes e guarda um backup do que existia antes
    -Reverter   desfaz tudo a partir do backup
  Nao precisa de administrador (tudo e do usuario atual).

.PARAMETER CaminhoCs2
  Caminho completo do cs2.exe, se o script nao achar sozinho pela Steam.

.EXAMPLE
  .\cs2-otimizar.ps1                 # simulacao
  .\cs2-otimizar.ps1 -Aplicar        # aplica
  .\cs2-otimizar.ps1 -Reverter       # desfaz
#>
[CmdletBinding()]
param(
    [switch]$Aplicar,
    [switch]$Reverter,
    [string]$CaminhoCs2
)

$ErrorActionPreference = 'Stop'
$pastaBackup = Join-Path $env:LOCALAPPDATA 'scripts-otimizacao'
$arquivoBackup = Join-Path $pastaBackup 'cs2-backup.json'
$simulacao = -not ($Aplicar -or $Reverter)

if ($Aplicar -and $Reverter) { Write-Error 'Use -Aplicar ou -Reverter, nao os dois.'; return }

function Info($t) { Write-Host $t }
function Acao($t) {
    if ($simulacao) { Write-Host "[simulacao] $t" -ForegroundColor Yellow } else { Write-Host "[ok] $t" -ForegroundColor Green }
}

# ---------- helpers de registro ----------
function Ler-Reg($caminho, $nome) {
    # devolve um objeto com existia/valor/tipo para poder restaurar depois
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

# ---------- localizar o cs2.exe ----------
function Achar-Cs2 {
    if ($CaminhoCs2) { if (Test-Path $CaminhoCs2) { return (Resolve-Path $CaminhoCs2).Path } else { return $null } }
    $biblios = @()
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($steam) {
        $biblios += $steam
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $biblios += $m.Groups[1].Value.Replace('\\', '\')
            }
        }
    }
    foreach ($b in $biblios) {
        $exe = Join-Path $b 'steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

# ---------- REVERTER ----------
if ($Reverter) {
    if (-not (Test-Path $arquivoBackup)) { Write-Host "Nenhum backup em $arquivoBackup. Nada a reverter."; return }
    $b = Get-Content $arquivoBackup -Raw | ConvertFrom-Json

    foreach ($e in @($b.registro)) {
        Restaurar-Reg $e
        Acao "Registro restaurado: $($e.caminho) [$($e.nome)]"
    }
    if ($b.planoEnergiaAnterior) {
        powercfg /setactive $b.planoEnergiaAnterior | Out-Null
        Acao "Plano de energia anterior reativado ($($b.planoEnergiaAnterior))"
    }
    if ($b.planoCriadoPorNos) {
        powercfg /delete $b.planoCriadoPorNos 2>$null | Out-Null
        Acao "Plano de energia criado pelo script removido"
    }
    if ($b.autoexec) {
        if ($b.autoexec.backup -and (Test-Path $b.autoexec.backup)) {
            Copy-Item $b.autoexec.backup $b.autoexec.destino -Force
            Remove-Item $b.autoexec.backup -Force
            Acao "autoexec.cfg antigo restaurado"
        } elseif (Test-Path $b.autoexec.destino) {
            Remove-Item $b.autoexec.destino -Force
            Acao "autoexec.cfg criado pelo script removido"
        }
    }
    Get-Process cs2 -ErrorAction SilentlyContinue | ForEach-Object { $_.PriorityClass = 'Normal'; Acao "Prioridade do cs2 (PID $($_.Id)) de volta para Normal" }
    Remove-Item $arquivoBackup -Force
    Info 'Tudo revertido.'
    return
}

# ---------- APLICAR / SIMULACAO ----------
if ($simulacao) { Info '=== SIMULACAO: nada sera alterado. Use -Aplicar para aplicar. ===' }
if (-not $simulacao -and (Test-Path $arquivoBackup)) {
    Write-Error "Ja existe um backup em $arquivoBackup (ajustes ja aplicados). Rode -Reverter antes de aplicar de novo."
    return
}

$backup = @{ registro = @(); planoEnergiaAnterior = $null; planoCriadoPorNos = $null; autoexec = $null }
$exe = Achar-Cs2

function Ajustar-Reg($caminho, $nome, $valor, $tipo, $descricao) {
    $antes = Ler-Reg $caminho $nome
    if ($antes.existia -and $antes.valor -eq $valor) { Info "Ja estava assim: $descricao"; return }
    Acao $descricao
    if (-not $simulacao) {
        $script:backup.registro += @{ caminho = $caminho; nome = $nome; existia = $antes.existia; valor = $antes.valor; tipo = $antes.tipo }
        Gravar-Reg $caminho $nome $valor $tipo
    }
}

# 1. Preferencia de GPU (alto desempenho) para o cs2.exe
if ($exe) {
    Ajustar-Reg 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' $exe 'GpuPreference=2;' 'String' "GPU de alto desempenho para $exe"
} else {
    Info 'cs2.exe nao encontrado (Steam instalada?). Passe -CaminhoCs2 para o ajuste de GPU e do autoexec.'
}

# 2. Plano de energia de alto desempenho
$ativo = (powercfg /getactivescheme) -replace '.*:\s*([0-9a-fA-F-]{36}).*', '$1'
$altoDesempenho = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
if ($ativo -eq $altoDesempenho) {
    Info 'Plano de energia ja e Alto desempenho.'
} else {
    Acao "Plano de energia: $ativo -> Alto desempenho"
    if (-not $simulacao) {
        $backup.planoEnergiaAnterior = $ativo
        $existe = (powercfg /list) -match $altoDesempenho
        if (-not $existe) {
            # em PCs com Modern Standby o plano some da lista; recria a partir do modelo
            $saida = powercfg /duplicatescheme $altoDesempenho
            $novo = ($saida -replace '.*:\s*([0-9a-fA-F-]{36}).*', '$1')
            $backup.planoCriadoPorNos = $novo
            powercfg /setactive $novo | Out-Null
        } else {
            powercfg /setactive $altoDesempenho | Out-Null
        }
    }
}

# 3. Desligar Game DVR / gravacao em segundo plano do usuario
Ajustar-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'DWord' 'Game DVR desligado (GameConfigStore)'
Ajustar-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'DWord' 'Captura em segundo plano desligada (GameDVR)'

# 4. autoexec.cfg
if ($exe) {
    $destino = Join-Path (Split-Path $exe -Parent | Split-Path -Parent | Split-Path -Parent) 'csgo\cfg\autoexec.cfg'
    $origem = Join-Path $PSScriptRoot 'autoexec.cfg'
    if (Test-Path $origem) {
        Acao "autoexec.cfg copiado para $destino"
        if (-not $simulacao) {
            $backup.autoexec = @{ destino = $destino; backup = $null }
            if (Test-Path $destino) {
                $bak = "$destino.bak-scripts"
                Copy-Item $destino $bak -Force
                $backup.autoexec.backup = $bak
            }
            Copy-Item $origem $destino -Force
        }
    }
}

# 5. Prioridade alta do processo em execucao (vale ate fechar o jogo)
$proc = Get-Process cs2 -ErrorAction SilentlyContinue
if ($proc) {
    foreach ($p in $proc) {
        Acao "Prioridade do cs2 (PID $($p.Id)) -> Alta"
        if (-not $simulacao) { $p.PriorityClass = 'High' }
    }
} else {
    Info 'cs2 nao esta rodando. Para prioridade alta sempre, use -high nas opcoes de inicializacao (launch-options.txt).'
}

if (-not $simulacao) {
    New-Item -ItemType Directory -Path $pastaBackup -Force | Out-Null
    $backup | ConvertTo-Json -Depth 5 | Set-Content -Path $arquivoBackup -Encoding UTF8
    Info "Backup salvo em $arquivoBackup. Para desfazer: .\cs2-otimizar.ps1 -Reverter"
}
