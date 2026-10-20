# Músicas e pendrive

Todos os scripts rodam em **simulação** por padrão e só agem com `-Aplicar`.

| Script | Para quê |
|---|---|
| `../pendrive/sincronizar-pendrive.ps1` | Copia sua biblioteca (`%USERPROFILE%\Music` ou `-Origem`) para o pendrive, em `funk`, `bandinha-gaucha`, `sertanejo`, `forro`, `outros`. Só mp3/m4a/flac, sem duplicar, gera `playlist.m3u`. Nunca apaga nem formata nada |
| `baixar-musicas-cc.ps1` | Baixa mp3 com `yt-dlp` apenas de vídeos Creative Commons. Instala yt-dlp/ffmpeg via winget com `-Aplicar`. Registra recusados e créditos |
| `organizar-lista.ps1` + `lista-2026.txt` | Lista de desejos, só organiza, não baixa |
| `FONTES-LEGAIS.md` | Onde obter música legalmente |

```powershell
..\pendrive\sincronizar-pendrive.ps1                  # simula
..\pendrive\sincronizar-pendrive.ps1 -Aplicar         # copia
Copy-Item urls-cc.exemplo.txt urls-cc.txt             # edite e depois:
.\baixar-musicas-cc.ps1 -Aplicar
```

Não há baixador de músicas comerciais: isso violaria os termos do YouTube e o direito autoral dos artistas.
