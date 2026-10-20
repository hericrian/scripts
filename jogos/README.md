# Otimização geral do Windows 11 para jogos

```powershell
.\otimizar-windows-jogos.ps1            # simulação: mostra, não altera
.\otimizar-windows-jogos.ps1 -Aplicar   # aplica, com backup em %LOCALAPPDATA%\scripts-otimizacao
.\otimizar-windows-jogos.ps1 -Reverter  # desfaz
```

Opções: `-DiasTemp 14` muda a idade mínima dos temporários, `-SemLimpezaTemp` pula a limpeza. Não precisa de administrador e não remove nada do sistema.

| Ajuste | Efeito |
|---|---|
| Modo de Jogo | Liga `AutoGameModeEnabled`; o Windows dá prioridade ao jogo e segura tarefas de segundo plano |
| Game Bar / Game DVR | Desliga a captura em segundo plano e a abertura pelo botão do controle |
| Plano de energia | Alto desempenho (recria o plano se o PC só tiver "Equilibrado"); o anterior volta no `-Reverter` |
| Aceleração do mouse | Desliga "Aprimorar precisão do ponteiro" e aplica na hora; os valores antigos ficam no backup |
| Temporários | Apaga arquivos do seu `%TEMP%` com mais de 7 dias, ignorando os que estão em uso. **Não é reversível**, mas são só arquivos descartáveis; a simulação mostra quantos e quantos MB |
| Relatórios | Lista os programas de inicialização e os 10 processos com mais RAM (somente leitura) |

Os relatórios aparecem também na simulação. Quem decide o que tirar da inicialização é você, em Configurações > Aplicativos > Inicialização.
