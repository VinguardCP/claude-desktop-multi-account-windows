# Instalar pelo Claude Code (sem mexer em nada) · Install through Claude Code

Copie o bloco do seu idioma, cole no **Claude Code** (terminal, app de desktop ou extensão do VS Code) e responda as perguntas. Ele baixa, confere, instala e testa tudo para você.

Copy the block in your language, paste it into **Claude Code** (terminal, desktop app or VS Code extension) and answer the questions. It downloads, checks, installs and tests everything for you.

## 🇧🇷 Português

````text
Quero usar várias contas do Claude Desktop ao mesmo tempo no meu Windows com a ferramenta Claude Contas
(https://github.com/VinguardCP/claude-desktop-multi-account-windows). Faça a instalação completa para mim:

1. Confira que estou no Windows e que o Claude Desktop está instalado (Get-AppxPackage com Publisher da
   Anthropic, ou %LOCALAPPDATA%\Microsoft\WindowsApps\claude-desktop.exe). Se não estiver, pare e me diga
   para instalar em https://claude.com/download e abrir uma vez.
2. Baixe https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main/claude-contas.ps1
   para uma pasta temporária com Invoke-WebRequest -OutFile (não altere o arquivo: ele precisa manter o BOM UTF-8).
   Leia o script antes de rodar e me diga em 3 linhas o que ele faz.
3. Me pergunte tudo de uma vez (use perguntas de múltipla escolha se puder):
   a) Nome da conta principal, a que já está no Claude (padrão: Principal).
   b) Quantas contas EXTRAS (1 a 8) e o nome de cada uma (ex.: Trabalho, Cliente X).
   c) Estilo dos ícones: "logo" (logo do Claude com selo colorido e a inicial; recomendado) ou
      "numerado" (ícones coloridos 1, 2, 3... do projeto).
   d) Atualização automática agendada: sim ou não. Se sim, em quais horários além de ao ligar o
      computador (ex.: 12:00 no almoço, 18:30). Ela é silenciosa e não abre janelas.
   e) Instalar a skill /claude-contas do Claude Code, que conserta tudo se o Claude mudar (recomendado).
4. Rode, com as minhas respostas (sem perguntas no terminal):
   powershell -NoProfile -ExecutionPolicy Bypass -File "<arquivo baixado>" -Instalar -Sim
     -NomePrincipal "<a>" -Contas "<nomes separados por vírgula>" -Icones <logo|numerado>
     -Agendar "<horários separados por vírgula>"   (ou -SemAgendador)
     -ComSkill                                     (ou -SemSkill)
     -SemEntrar
   Se já existir a pasta %USERPROFILE%\Claude-Work (versão antiga), ela vira uma conta chamada "Work".
5. Rode "-Testar" e "-Diagnostico" no script instalado (%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1)
   e me mostre um resumo.
6. Para cada conta extra, me explique o login: o assistente fecha todas as janelas do Claude, abre só a
   conta nova e entrega a ela o link de login que o navegador devolve. Peça minha confirmação e então rode
   em segundo plano (ele espera até 15 minutos):
   powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1" -Entrar "<nome>" -Sim
   Diga para eu entrar na janela que abriu com o e-mail daquela conta. Quando terminar, rode -Diagnostico
   e confirme que a conta aparece "logada" e não é a mesma da principal. Uma conta por vez.
7. No fim, me diga onde estão os atalhos ("Claude - <nome>" na Área de Trabalho e no menu Iniciar),
   como abrir o menu (menu Iniciar > Claude Contas > Claude Contas (menu)) e como desinstalar.

Nunca apague pastas de conta nem feche janelas do Claude sem me perguntar antes.
````

## 🇺🇸 English

````text
I want to use several Claude Desktop accounts at the same time on Windows with the Claude Contas tool
(https://github.com/VinguardCP/claude-desktop-multi-account-windows). Do the full install for me:

1. Check that I am on Windows and Claude Desktop is installed (Get-AppxPackage with an Anthropic publisher,
   or %LOCALAPPDATA%\Microsoft\WindowsApps\claude-desktop.exe). If not, stop and tell me to install it from
   https://claude.com/download and open it once.
2. Download https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main/claude-contas.ps1
   to a temp folder with Invoke-WebRequest -OutFile (do not modify it: it must keep its UTF-8 BOM).
   Read the script before running it and tell me in 3 lines what it does.
3. Ask me everything at once (multiple-choice questions if you can):
   a) Name of the main account, the one already in Claude (default: Main).
   b) How many EXTRA accounts (1 to 8) and the name of each (e.g. Work, Client X).
   c) Icon style: "logo" (Claude logo with a colored badge and the initial; recommended) or
      "numerado" (the project's colored 1, 2, 3... icons).
   d) Scheduled automatic update: yes or no. If yes, at which times besides sign-in
      (e.g. 12:00 at lunch, 18:30). It is silent and opens no windows.
   e) Install the /claude-contas Claude Code skill, which fixes things if Claude changes (recommended).
4. Run, with my answers (no questions in the terminal):
   powershell -NoProfile -ExecutionPolicy Bypass -File "<downloaded file>" -Instalar -Sim
     -NomePrincipal "<a>" -Contas "<comma-separated names>" -Icones <logo|numerado>
     -Agendar "<comma-separated times>"   (or -SemAgendador)
     -ComSkill                            (or -SemSkill)
     -SemEntrar
   If %USERPROFILE%\Claude-Work exists (old version), it becomes an account named "Work".
5. Run "-Testar" and "-Diagnostico" on the installed script (%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1)
   and show me a summary.
6. For each extra account, explain the sign-in: the helper closes every Claude window, opens only the new
   account and hands it the sign-in link the browser sends back. Ask for my OK, then run it in the
   background (it waits up to 15 minutes):
   powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1" -Entrar "<name>" -Sim
   Tell me to sign in, in the window that opened, with that account's email. When it finishes, run
   -Diagnostico and confirm the account shows as signed in and is not the same as the main one. One at a time.
7. At the end, tell me where the shortcuts are ("Claude - <name>" on the Desktop and Start menu), how to open
   the menu (Start menu > Claude Contas > Claude Contas (menu)) and how to uninstall.

Never delete account folders or close Claude windows without asking me first.
````
