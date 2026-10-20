<#
.SYNOPSIS
  Organiza e resume a lista de desejos (lista-2026.txt). Nao baixa nada, nao altera arquivos.
.EXAMPLE
  .\organizar-lista.ps1
  .\organizar-lista.ps1 -Lista .\lista-2026.txt
#>
[CmdletBinding()]
param([string]$Lista)
if (-not $Lista) { $Lista = Join-Path $PSScriptRoot 'lista-2026.txt' }

if (-not (Test-Path -LiteralPath $Lista)) { Write-Host "Lista nao encontrada: $Lista"; return }
$itens = Get-Content -LiteralPath $Lista -Encoding UTF8 | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') } | ForEach-Object {
    if ($_ -match '^\s*([^|]+?)\s*\|\s*(.+?)\s*$') { [pscustomobject]@{ Genero = $Matches[1].ToLowerInvariant(); Musica = $Matches[2] } }
    else { [pscustomobject]@{ Genero = 'outros'; Musica = $_.Trim() } }
}
if (-not $itens) { Write-Host 'A lista esta vazia. Preencha lista-2026.txt.'; return }
foreach ($g in ($itens | Group-Object Genero | Sort-Object Name)) {
    Write-Host "`n$($g.Name) ($($g.Count))" -ForegroundColor Cyan
    $g.Group | Sort-Object Musica -Unique | ForEach-Object { Write-Host "  - $($_.Musica)" }
}
Write-Host "`nTotal: $(@($itens).Count). Veja FONTES-LEGAIS.md para onde obter cada faixa de forma legal."
