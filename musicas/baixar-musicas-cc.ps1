<#
.SYNOPSIS
  Baixa audio (mp3) do YouTube SOMENTE de videos com licenca Creative Commons.

.DESCRIPTION
  Le uma lista (padrao: urls-cc.txt, ao lado do script), uma entrada por linha:
      genero|URL            ex.: forro|https://www.youtube.com/watch?v=...
      genero|texto de busca ex.: sertanejo|musica sertaneja licenca creative commons
      URL                   (genero = outros)
  Linhas vazias e as que comecam com # sao ignoradas. Generos: funk, bandinha-gaucha,
  sertanejo, forro, outros.

  Cada item passa por --match-filter "license = 'Creative Commons Attribution license (reuse allowed)'":
  o yt-dlp so baixa o que o proprio uploader marcou como Creative Commons. O que nao passa e
  registrado em recusados-AAAAMMDD.log. Os creditos (autor | titulo | link), que a licenca
  CC-BY exige, vao para creditos.txt na pasta de saida.

  Sem -Aplicar roda em SIMULACAO: se o yt-dlp estiver instalado, consulta e mostra o que
  passaria no filtro, sem baixar. Se faltar yt-dlp/ffmpeg, so avisa que instalaria via winget.

.PARAMETER Lista   Arquivo de lista. Padrao: urls-cc.txt ao lado do script.
.PARAMETER Saida   Pasta de saida. Padrao: $env:USERPROFILE\Music\CC
.PARAMETER Aplicar Baixa de verdade (e instala yt-dlp/ffmpeg via winget se faltarem).

.EXAMPLE
  .\baixar-musicas-cc.ps1
  .\baixar-musicas-cc.ps1 -Lista .\minha-lista.txt -Aplicar
#>
[CmdletBinding()]
param(
    [string]$Lista,
    [string]$Saida = (Join-Path $env:USERPROFILE 'Music\CC'),
    [switch]$Aplicar
)

$ErrorActionPreference = 'Stop'
if (-not $Lista) { $Lista = Join-Path $PSScriptRoot 'urls-cc.txt' }
$simulacao = -not $Aplicar
$filtro = "license = 'Creative Commons Attribution license (reuse allowed)'"
$generosValidos = 'funk', 'bandinha-gaucha', 'sertanejo', 'forro', 'outros'

function Atualizar-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }

function Garantir-Ferramenta($comando, $idWinget) {
    if (Get-Command $comando -ErrorAction SilentlyContinue) { return $true }
    if ($simulacao) { Write-Host "[simulacao] $comando nao encontrado; -Aplicar instalaria com: winget install --id $idWinget -e" -ForegroundColor Yellow; return $false }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Error "$comando nao encontrado e o winget nao esta disponivel. Instale $comando manualmente."; return $false }
    Write-Host "Instalando $comando via winget..."
    winget install --id $idWinget -e --accept-source-agreements --accept-package-agreements
    Atualizar-Path
    if (-not (Get-Command $comando -ErrorAction SilentlyContinue)) {
        Write-Error "$comando foi instalado mas ainda nao aparece no PATH. Feche e abra o PowerShell e rode de novo."
        return $false
    }
    return $true
}

if (-not (Test-Path -LiteralPath $Lista)) {
    Write-Host "Lista nao encontrada: $Lista" -ForegroundColor Red
    Write-Host 'Crie o arquivo com uma entrada por linha (genero|URL ou genero|busca). Veja urls-cc.exemplo.txt.'
    return
}

$entradas = Get-Content -LiteralPath $Lista -Encoding UTF8 | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') }
if (-not $entradas) { Write-Host 'A lista esta vazia (so comentarios). Preencha e rode de novo.'; return }

if ($simulacao) { Write-Host '=== SIMULACAO: nada sera baixado. Use -Aplicar para baixar. ===' -ForegroundColor Yellow }

$temYt = Garantir-Ferramenta 'yt-dlp' 'yt-dlp.yt-dlp'
$temFf = Garantir-Ferramenta 'ffmpeg' 'Gyan.FFmpeg'
if ($Aplicar -and -not ($temYt -and $temFf)) { return }

$hoje = Get-Date -Format 'yyyyMMdd'
$logRecusados = Join-Path $Saida "recusados-$hoje.log"
$creditos = Join-Path $Saida 'creditos.txt'
if ($Aplicar) { New-Item -ItemType Directory -Path $Saida -Force | Out-Null }

foreach ($linha in $entradas) {
    $genero = 'outros'; $alvo = $linha.Trim()
    if ($alvo -match '^([^|]+)\|(.+)$') { $genero = $Matches[1].Trim().ToLowerInvariant(); $alvo = $Matches[2].Trim() }
    if ($generosValidos -notcontains $genero) { Write-Host "Genero desconhecido '$genero' em: $linha (usando 'outros')" -ForegroundColor Red; $genero = 'outros' }
    if ($alvo -notmatch '^(https?://|ytsearch)') { $alvo = "ytsearch5:$alvo" }

    $pasta = Join-Path $Saida $genero
    Write-Host "`n[$genero] $alvo"

    $args = @(
        '--match-filter', $filtro,
        '--ignore-errors',
        '--download-archive', (Join-Path $Saida 'ja-baixados.txt'),
        '-x', '--audio-format', 'mp3', '--audio-quality', '0',
        '--embed-metadata',
        '-o', (Join-Path $pasta '%(title)s [%(id)s].%(ext)s'),
        '--no-quiet', '--no-simulate',
        '--print-to-file', 'after_move:%(uploader)s | %(title)s | %(webpage_url)s | licenca: %(license)s', $creditos
    )
    if ($simulacao) {
        if (-not $temYt) { continue }
        # so consulta: mostra o que passa no filtro, sem baixar
        $args = @('--match-filter', $filtro, '--ignore-errors', '--simulate', '--print', '%(title)s  [%(license)s]', $alvo)
    } else {
        $args += $alvo
    }

    $saidaYt = & yt-dlp @args 2>&1 | ForEach-Object { "$_" }
    $saidaYt | ForEach-Object { Write-Host "  $_" }

    $recusados = $saidaYt | Where-Object { $_ -match 'does not pass filter' }
    foreach ($r in $recusados) {
        Write-Host "  RECUSADO (sem licenca CC): $r" -ForegroundColor Yellow
        if ($Aplicar) { Add-Content -LiteralPath $logRecusados -Value "$(Get-Date -Format s) [$genero] $r" -Encoding UTF8 }
    }
}

if ($Aplicar) {
    Write-Host "`nPronto. Musicas em: $Saida"
    Write-Host "Creditos (exigidos pela licenca CC-BY): $creditos"
    if (Test-Path $logRecusados) { Write-Host "Recusados: $logRecusados" }
}
