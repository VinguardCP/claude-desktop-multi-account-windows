# Instalar com ajuda de uma IA · Install with an AI's help

Funciona com qualquer IA. Escolha o prompt pelo tipo de IA que você usa, copie o bloco inteiro e cole.
Works with any AI. Pick the prompt for the kind of AI you use, copy the whole block and paste it.

| Sua IA · Your AI | Use · Use |
| --- | --- |
| Executa comandos no seu computador: Claude Code, Codex, Cursor, Windsurf, Gemini CLI, GitHub Copilot (modo agente) · Runs commands on your computer | **Prompt A** — a IA faz tudo · the AI does everything |
| Só conversa: ChatGPT, Gemini, Claude.ai, Copilot no navegador · Chat only | **Prompt B** — a IA monta um comando para você colar · the AI builds one command for you to paste |

---

## 🇧🇷 Prompt A — IA que executa comandos

````text
Quero usar várias contas do Claude Desktop ao mesmo tempo no meu Windows com a ferramenta Claude Contas.
Repositório: https://github.com/VinguardCP/claude-desktop-multi-account-windows

1. Leia o README.pt-BR.md do repositório e me explique em poucas linhas o que a ferramenta faz.
2. Confira que estou no Windows 10/11 e que o Claude Desktop está instalado (Get-AppxPackage com Publisher
   da Anthropic, ou %LOCALAPPDATA%\Microsoft\WindowsApps\claude-desktop.exe). Se não estiver, pare e me peça
   para instalar em https://claude.com/download e abrir uma vez.
3. Baixe https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main/claude-contas.ps1
   para uma pasta temporária com Invoke-WebRequest -OutFile (não edite o arquivo: ele precisa manter o BOM UTF-8).
   Leia o script antes de rodar e me diga em 3 linhas o que ele vai mudar no meu computador.
4. Me pergunte tudo de uma vez:
   a) Nome da conta principal, a que já está no Claude (padrão: Principal).
   b) Quantas contas EXTRAS (1 a 8) e o nome de cada uma (ex.: Trabalho, Cliente X).
   c) Estilo dos ícones: "logo" (logo do Claude com selo colorido e a inicial; recomendado) ou
      "numerado" (ícones coloridos 1, 2, 3... do projeto).
   d) Atualização automática agendada: sim ou não. Se sim, em quais horários além de quando o computador
      liga (ex.: 12:00 no almoço). Ela é silenciosa e não abre janelas.
   e) Se uso o Claude Code: instalar a skill /claude-contas, que conserta tudo se o Claude mudar.
5. Rode, com as minhas respostas, sem perguntas no terminal (tudo numa linha):
   powershell -NoProfile -ExecutionPolicy Bypass -File "<arquivo baixado>" -Instalar -Sim
     -NomePrincipal "<a>" -Contas "<nomes separados por vírgula>" -Icones <logo|numerado>
     -Agendar "<horários separados por vírgula>"  (ou -SemAgendador)
     -ComSkill  (ou -SemSkill)
     -SemEntrar
   Se já existir %USERPROFILE%\Claude-Work (versão antiga), ela vira uma conta chamada "Work".
6. Rode -Testar e -Diagnostico no script instalado (%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1)
   e me mostre um resumo.
7. Login de cada conta extra, uma por vez. Explique: o assistente fecha todas as janelas do Claude, abre
   só a conta nova, entrega a ela o link de login que o navegador devolve e espera 45 s para o Claude gravar
   o login. Peça meu OK e rode em segundo plano (ele espera até 15 minutos):
   powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1" -Entrar "<nome>" -Sim
   Diga para eu entrar, na janela que abriu, com o e-mail daquela conta. Quando terminar, rode
   -Diagnostico e confirme que a conta aparece "logada" e não é a mesma da principal.
8. No fim, me diga: onde estão os atalhos ("Claude - <nome>" na Área de Trabalho e no menu Iniciar),
   como abrir o menu (menu Iniciar > Claude Contas > Claude Contas (menu)), como criar outra conta depois,
   e que para fechar uma conta logo depois do login eu devo usar o ícone perto do relógio > Sair.

Nunca apague pastas de conta nem feche janelas do Claude sem me perguntar antes.
````

## 🇧🇷 Prompt B — IA só de chat

````text
Quero usar várias contas do Claude Desktop ao mesmo tempo no meu Windows com a ferramenta Claude Contas
(https://github.com/VinguardCP/claude-desktop-multi-account-windows). Você não executa comandos no meu
computador, então me guie:

1. Se você consegue abrir links, leia o README.pt-BR.md desse repositório. Me explique em poucas linhas o que
   a ferramenta faz: um atalho "Claude - <nome>" na Área de Trabalho para cada conta, todas abertas juntas,
   login de cada conta guardado numa pasta separada, atalhos que não quebram quando o Claude atualiza,
   atualização automática agendada opcional e um menu para criar, renomear e remover contas.
2. Me pergunte, uma de cada vez:
   a) Nome da conta principal, a que já está no Claude (padrão: Principal).
   b) Quantas contas extras e o nome de cada uma.
   c) Ícones "logo" (logo do Claude com selo colorido; recomendado) ou "numerado" (ícones 1, 2, 3...).
   d) Atualização automática agendada e em quais horários (ex.: 12:00), ou nenhuma.
   e) Se uso o Claude Code (para instalar a skill /claude-contas).
3. Monte UM comando para eu colar no PowerShell (tecla Windows, digite powershell, Enter), neste formato,
   numa linha só:
   $f="$env:TEMP\claude-contas.ps1"; irm https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main/claude-contas.ps1 -OutFile $f; powershell -NoProfile -ExecutionPolicy Bypass -File $f -Instalar -Sim -NomePrincipal "<a>" -Contas "<nomes, separados por vírgula>" -Icones <logo|numerado> -Agendar "<horários>" -SemSkill -SemEntrar
   Use -SemAgendador no lugar de -Agendar se eu não quiser, e -ComSkill no lugar de -SemSkill se eu usar o Claude Code.
4. Depois me explique o login de cada conta extra: menu Iniciar > Claude Contas > Claude Contas (menu),
   tecla E, escolher o número da conta, entrar na janela que abrir com o e-mail daquela conta e esperar o
   assistente terminar a contagem antes de fechar qualquer coisa.
5. Diga como conferir se deu certo: no mesmo menu, tecla D (diagnóstico) deve mostrar cada conta "logada".
````

---

## 🇺🇸 Prompt A — AI that runs commands

````text
I want to use several Claude Desktop accounts at the same time on Windows with the Claude Contas tool.
Repository: https://github.com/VinguardCP/claude-desktop-multi-account-windows

1. Read the repository's README.md and tell me in a few lines what the tool does.
2. Check that I am on Windows 10/11 and Claude Desktop is installed (Get-AppxPackage with an Anthropic
   publisher, or %LOCALAPPDATA%\Microsoft\WindowsApps\claude-desktop.exe). If not, stop and ask me to install
   it from https://claude.com/download and open it once.
3. Download https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main/claude-contas.ps1
   to a temp folder with Invoke-WebRequest -OutFile (do not edit it: it must keep its UTF-8 BOM).
   Read the script before running it and tell me in 3 lines what it will change on my computer.
4. Ask me everything at once:
   a) Name of the main account, the one already in Claude (default: Principal).
   b) How many EXTRA accounts (1 to 8) and the name of each (e.g. Work, Client X).
   c) Icon style: "logo" (Claude logo with a colored badge and the initial; recommended) or
      "numerado" (the project's colored 1, 2, 3... icons).
   d) Scheduled automatic update: yes or no. If yes, at which times besides when the computer starts
      (e.g. 12:00 at lunch). It is silent and opens no windows.
   e) If I use Claude Code: install the /claude-contas skill, which fixes things if Claude changes.
5. Run, with my answers, with no questions in the terminal (all on one line):
   powershell -NoProfile -ExecutionPolicy Bypass -File "<downloaded file>" -Instalar -Sim -Idioma en
     -NomePrincipal "<a>" -Contas "<comma-separated names>" -Icones <logo|numerado>
     -Agendar "<comma-separated times>"  (or -SemAgendador)
     -ComSkill  (or -SemSkill)
     -SemEntrar
   If %USERPROFILE%\Claude-Work exists (old version), it becomes an account named "Work".
6. Run -Testar and -Diagnostico on the installed script (%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1)
   and show me a summary.
7. Sign in to each extra account, one at a time. Explain: the helper closes every Claude window, opens only
   the new account, hands it the sign-in link the browser sends back and waits 45 s for Claude to save the
   sign-in. Ask for my OK and run it in the background (it waits up to 15 minutes):
   powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1" -Entrar "<name>" -Sim -Idioma en
   Tell me to sign in, in the window that opened, with that account's email. When it finishes, run
   -Diagnostico and confirm the account shows as signed in and is not the same as the main one.
8. At the end, tell me: where the shortcuts are ("Claude - <name>" on the Desktop and Start menu), how to open
   the menu (Start menu > Claude Contas > Claude Contas (menu)), how to add another account later, and that
   right after a sign-in I should close an account with the icon near the clock > Quit.

Never delete account folders or close Claude windows without asking me first.
````

## 🇺🇸 Prompt B — chat-only AI

````text
I want to use several Claude Desktop accounts at the same time on Windows with the Claude Contas tool
(https://github.com/VinguardCP/claude-desktop-multi-account-windows). You cannot run commands on my computer,
so guide me:

1. If you can open links, read the repository's README.md. Tell me in a few lines what the tool does: a
   "Claude - <name>" Desktop shortcut for each account, all open at once, each account's sign-in kept in its
   own folder, shortcuts that survive Claude updates, an optional scheduled automatic update and a menu to
   add, rename and remove accounts.
2. Ask me, one at a time:
   a) Name of the main account, the one already in Claude (default: Principal).
   b) How many extra accounts and the name of each.
   c) Icons "logo" (Claude logo with a colored badge; recommended) or "numerado" (1, 2, 3... icons).
   d) Scheduled automatic update and at which times (e.g. 12:00), or none.
   e) Whether I use Claude Code (to install the /claude-contas skill).
3. Build ONE command for me to paste into PowerShell (Windows key, type powershell, Enter), in this format,
   on a single line:
   $f="$env:TEMP\claude-contas.ps1"; irm https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main/claude-contas.ps1 -OutFile $f; powershell -NoProfile -ExecutionPolicy Bypass -File $f -Instalar -Sim -Idioma en -NomePrincipal "<a>" -Contas "<comma-separated names>" -Icones <logo|numerado> -Agendar "<times>" -SemSkill -SemEntrar
   Use -SemAgendador instead of -Agendar if I do not want it, and -ComSkill instead of -SemSkill if I use Claude Code.
4. Then explain how to sign in to each extra account: Start menu > Claude Contas > Claude Contas (menu),
   key E, pick the account number, sign in in the window that opens with that account's email and wait for
   the helper to finish its countdown before closing anything.
5. Tell me how to check it worked: in the same menu, key D (diagnostics) should show each account signed in.
````
