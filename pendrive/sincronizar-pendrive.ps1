<#
.SYNOPSIS
  Copia a sua biblioteca de musicas para o pendrive, organizada por genero, e gera playlist.m3u.

.DESCRIPTION
  Sem -Aplicar roda em SIMULACAO: lista o que seria copiado e nao escreve nada.
  - Detecta o pendrive (unidade removivel). Se houver mais de um, informe -Unidade.
  - Copia so .mp3, .m4a e .flac.
  - Pastas no pendrive: funk, bandinha-gaucha, sertanejo, forro, outros.
  - Genero vem da tag de genero do arquivo; se nao houver, de palavras no caminho/nome.
  - Nao duplica: arquivo com mesmo nome e tamanho que ja esteja em QUALQUER pasta do pendrive e pulado.
  - Nunca apaga nada, nem na origem nem no pendrive.

.PARAMETER Origem   Pasta com as musicas. Padrao: $env:USERPROFILE\Music
.PARAMETER Unidade  Letra do pendrive (ex.: E). Padrao: detectado automaticamente.
.PARAMETER Destino  Pasta de destino qualquer (so para teste; ignora a deteccao do pendrive).
.PARAMETER SemTags  Nao le a tag de genero (mais rapido; usa so o caminho/nome).
.PARAMETER LimparPendrive  APAGA tudo que esta no pendrive antes de copiar (so em unidade removivel detectada; pede para digitar a letra da unidade). Sem -Aplicar so mostra o que seria apagado.
.PARAMETER Aplicar  Copia de verdade e grava o playlist.m3u.

.EXAMPLE
  .\sincronizar-pendrive.ps1
  .\sincronizar-pendrive.ps1 -Origem D:\Musicas -Aplicar
#>
[CmdletBinding()]
param(
    [string]$Origem = (Join-Path $env:USERPROFILE 'Music'),
    [string]$Unidade,
    [string]$Destino,
    [switch]$SemTags,
    [switch]$LimparPendrive,
    [switch]$Aplicar
)

$ErrorActionPreference = 'Stop'
$extensoes = '.mp3', '.m4a', '.flac'
$simulacao = -not $Aplicar

function Sem-Acento([string]$t) {
    $n = $t.Normalize([Text.NormalizationForm]::FormD)
    (-join ($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })).ToLowerInvariant()
}

# Palavras-chave por genero. A ordem importa: bandinha antes de sertanejo e forro.
$generos = [ordered]@{
    'bandinha-gaucha' = 'bandinha|gaucha|gaucho|vanera|vaneira|tche|chamame|tradicionalista'
    'funk'            = 'funk|baile|pancadao|mandelao|\bmc '
    'sertanejo'       = 'sertanej|modao|universitario|sofrencia|moda de viola'
    'forro'           = 'forro|piseiro|xote|baiao|arrocha'
}

function Classificar([string]$texto) {
    $t = Sem-Acento $texto
    foreach ($g in $generos.Keys) { if ($t -match $generos[$g]) { return $g } }
    return 'outros'
}

# ---------- tag de genero via Shell (opcional) ----------
$shell = $null; $colGenero = $null
if (-not $SemTags) {
    try { $shell = New-Object -ComObject Shell.Application } catch { $shell = $null }
}
function Ler-Genero([IO.FileInfo]$arq) {
    if (-not $script:shell) { return '' }
    try {
        $pasta = $script:shell.NameSpace($arq.DirectoryName)
        if ($null -eq $script:colGenero) {
            $script:colGenero = -1
            for ($i = 0; $i -lt 320; $i++) {
                $h = $pasta.GetDetailsOf($null, $i)
                if ($h -match '^(G.nero|Genre)$') { $script:colGenero = $i; break }
            }
        }
        if ($script:colGenero -lt 0) { return '' }
        return [string]$pasta.GetDetailsOf($pasta.ParseName($arq.Name), $script:colGenero)
    } catch { return '' }
}

# ---------- origem ----------
if (-not (Test-Path -LiteralPath $Origem)) { Write-Error "Pasta de origem nao existe: $Origem"; return }
$Origem = (Resolve-Path -LiteralPath $Origem).Path

# ---------- destino ----------
if ($Destino) {
    if (-not (Test-Path -LiteralPath $Destino)) { if ($Aplicar) { New-Item -ItemType Directory $Destino -Force | Out-Null } }
    $raiz = $Destino
    Write-Host "Destino manual: $raiz"
} else {
    $removiveis = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2' -ErrorAction SilentlyContinue)
    if ($Unidade) { $removiveis = @($removiveis | Where-Object { $_.DeviceID -eq ($Unidade.TrimEnd(':', '\') + ':') }) }
    if ($removiveis.Count -eq 0) {
        Write-Host 'Nenhum pendrive (unidade removivel) encontrado. Conecte-o ou use -Unidade E.' -ForegroundColor Red
        return
    }
    if ($removiveis.Count -gt 1) {
        Write-Host 'Mais de uma unidade removivel encontrada. Escolha com -Unidade:' -ForegroundColor Red
        $removiveis | ForEach-Object { Write-Host ("  {0}  {1}  {2} GB livres" -f $_.DeviceID, $_.VolumeName, [math]::Round($_.FreeSpace / 1GB, 1)) }
        return
    }
    $d = $removiveis[0]
    $raiz = $d.DeviceID + '\'
    Write-Host ("Pendrive: {0} ({1}), {2} GB livres" -f $d.DeviceID, $d.VolumeName, [math]::Round($d.FreeSpace / 1GB, 1))
}

if ($simulacao) { Write-Host '=== SIMULACAO: nada sera copiado. Use -Aplicar para copiar. ===' -ForegroundColor Yellow }

# ---------- limpeza opcional do pendrive ----------
if ($LimparPendrive) {
    if ($Destino) { Write-Error '-LimparPendrive so vale para pendrive detectado, nao para -Destino.'; return }
    $itensApagar = @(Get-ChildItem -LiteralPath $raiz -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'System Volume Information' -and $_.Name -ne '$RECYCLE.BIN' })
    $tam = (Get-ChildItem -LiteralPath $raiz -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host ("LIMPAR: {0} itens na raiz de {1} ({2} MB) seriam APAGADOS." -f $itensApagar.Count, $d.DeviceID, [math]::Round(([double]$tam) / 1MB, 1)) -ForegroundColor Red
    if ($Aplicar) {
        $resp = Read-Host "Digite a letra da unidade ($($d.DeviceID.TrimEnd(':'))) para confirmar que quer apagar TUDO do pendrive"
        if ($resp.TrimEnd(':').ToUpperInvariant() -ne $d.DeviceID.TrimEnd(':').ToUpperInvariant()) { Write-Host 'Confirmacao nao confere. Nada foi apagado.'; return }
        $itensApagar | Remove-Item -Recurse -Force
        Write-Host 'Pendrive limpo.'
    }
}
# ---------- indice do que ja existe no pendrive (nome|tamanho) ----------
$existentes = @{}
if (Test-Path -LiteralPath $raiz) {
    Get-ChildItem -LiteralPath $raiz -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extensoes -contains $_.Extension.ToLowerInvariant() } |
        ForEach-Object { $existentes["$($_.Name.ToLowerInvariant())|$($_.Length)"] = $true }
}

# ---------- varredura ----------
$arquivos = Get-ChildItem -LiteralPath $Origem -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extensoes -contains $_.Extension.ToLowerInvariant() }
Write-Host "Encontradas $(@($arquivos).Count) musicas em $Origem"

$resumo = @{}; $copiar = New-Object System.Collections.Generic.List[object]; $pulados = 0
foreach ($a in $arquivos) {
    $chave = "$($a.Name.ToLowerInvariant())|$($a.Length)"
    if ($existentes.ContainsKey($chave)) { $pulados++; continue }
    $existentes[$chave] = $true   # evita copiar duas vezes o mesmo arquivo repetido na origem
    $tag = Ler-Genero $a
    $rel = $a.FullName.Substring($Origem.Length)
    $g = Classificar "$tag $rel"
    $copiar.Add([pscustomobject]@{ Arquivo = $a; Genero = $g })
    $resumo[$g] = 1 + [int]$resumo[$g]
}

$bytes = ($copiar | ForEach-Object { $_.Arquivo.Length } | Measure-Object -Sum).Sum
Write-Host ("A copiar: {0} arquivos ({1} MB). Ja estavam no pendrive: {2}." -f $copiar.Count, [math]::Round(([double]$bytes) / 1MB, 1), $pulados)
$resumo.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host ("  {0,-16} {1}" -f $_.Name, $_.Value) }

if (-not $Destino -and $bytes -gt $d.FreeSpace) {
    Write-Host 'ATENCAO: nao cabe tudo no espaco livre do pendrive.' -ForegroundColor Red
    if ($Aplicar) { return }
}

if ($simulacao) {
    $copiar | Select-Object -First 15 | ForEach-Object { Write-Host ("  [{0}] {1}" -f $_.Genero, $_.Arquivo.Name) }
    if ($copiar.Count -gt 15) { Write-Host "  ... e mais $($copiar.Count - 15)" }
    return
}

# ---------- copia ----------
$n = 0
foreach ($item in $copiar) {
    $a = $item.Arquivo
    $pasta = Join-Path $raiz $item.Genero
    New-Item -ItemType Directory -Path $pasta -Force | Out-Null
    $alvo = Join-Path $pasta $a.Name
    $k = 2
    while (Test-Path -LiteralPath $alvo) {   # mesmo nome, conteudo diferente: nao sobrescreve
        $alvo = Join-Path $pasta ("{0} ({1}){2}" -f $a.BaseName, $k, $a.Extension); $k++
    }
    Copy-Item -LiteralPath $a.FullName -Destination $alvo
    $n++
    if ($n % 25 -eq 0) { Write-Host "  $n / $($copiar.Count)" }
}
Write-Host "$n arquivos copiados."

# ---------- playlist.m3u ----------
$linhas = New-Object System.Collections.Generic.List[string]
$linhas.Add('#EXTM3U')
foreach ($g in ($generos.Keys + 'outros')) {
    $p = Join-Path $raiz $g
    if (-not (Test-Path -LiteralPath $p)) { continue }
    Get-ChildItem -LiteralPath $p -File | Where-Object { $extensoes -contains $_.Extension.ToLowerInvariant() } | Sort-Object Name | ForEach-Object {
        $linhas.Add("#EXTINF:-1,$($_.BaseName)")
        $linhas.Add("$g/$($_.Name)")
    }
}
[IO.File]::WriteAllLines((Join-Path $raiz 'playlist.m3u'), $linhas, (New-Object Text.UTF8Encoding $false))
Write-Host ("playlist.m3u gerado com {0} faixas." -f (($linhas.Count - 1) / 2))
