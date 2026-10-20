# CS2: otimização para Windows 11

Três arquivos:

- `cs2-otimizar.ps1`: ajustes do Windows. Roda em **simulação** por padrão.
- `autoexec.cfg`: cvars voltadas a FPS e conforto, sem nada de "config mágica".
- `launch-options.txt`: cole em Steam > CS2 > Propriedades > Opções de inicialização.

## Uso

```powershell
.\cs2-otimizar.ps1            # mostra o que mudaria, não altera nada
.\cs2-otimizar.ps1 -Aplicar   # aplica e guarda backup em %LOCALAPPDATA%\scripts-otimizacao
.\cs2-otimizar.ps1 -Reverter  # volta tudo ao que era
```

Se o script não achar o jogo: `-CaminhoCs2 "D:\Steam\...\game\bin\win64\cs2.exe"`.
Não precisa de administrador.

## O que cada ajuste faz

| Ajuste | Onde | Efeito |
|---|---|---|
| Preferência de GPU | `HKCU\Software\Microsoft\DirectX\UserGpuPreferences` | Força a GPU dedicada para o `cs2.exe` (útil em notebook com GPU integrada) |
| Plano de energia | `powercfg` | Ativa "Alto desempenho"; o plano anterior é reativado no `-Reverter` |
| Game DVR | `GameConfigStore` e `GameDVR` | Desliga a gravação em segundo plano, que consome GPU/disco |
| Prioridade | processo `cs2` em execução | Prioridade Alta até fechar o jogo. Para ser permanente, o `-high` está nas opções de inicialização |
| `autoexec.cfg` | pasta `csgo\cfg` do jogo | Copia o arquivo; o seu antigo vira `.bak-scripts` e volta no `-Reverter` |

## Opções de inicialização

`-novid` pula a abertura, `-high` prioridade alta, `+exec autoexec` carrega o cfg, `-nojoy` não inicializa controle. Não incluí `-threads` nem `-tickrate`: o jogo gerencia os núcleos sozinho e o tickrate não existe mais no CS2.

## Fora do escopo

Nada de mexer em TCP/IP, "otimizar" latência por registro, desativar serviços ou limpar o sistema. Esses ajustes não têm ganho comprovado e podem causar problemas.
