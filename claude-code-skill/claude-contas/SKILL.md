---
name: claude-contas
description: Checks, repairs and updates the Claude Contas tool (several Claude Desktop accounts side by side on Windows, repo VinguardCP/claude-desktop-multi-account-windows). Use when the user says the second Claude account stopped opening, opens the wrong account, lost its sign-in, Claude Desktop updated and something broke, or asks to check, fix or update "Claude Contas", "Claude Work", "multi account" or "multi-conta". Also use to publish a fixed version so every user gets it through the daily auto-update.
---

# Claude Contas: check, repair, update

Claude Contas opens extra Claude Desktop accounts by starting the app with
`--user-data-dir=<folder>` (one folder per account) through the MSIX alias
`%LOCALAPPDATA%\Microsoft\WindowsApps\claude-desktop.exe`, which does not change
with app versions. Installed files:

- Tool: `%LOCALAPPDATA%\ClaudeContas\claude-contas.ps1` (config `contas.json`, log `claude-contas.log`)
- Account folders: listed in `contas.json` (new ones under `%USERPROFILE%\ClaudeContas\<name>`);
  the main account (`principal`, number 1) uses the app's default folder
- Shortcuts: Desktop and Start menu `Claude Contas\Claude - <name>.lnk`, one per account including
  the main one; icon style `logo` (badge on the local Claude logo) or `numerado` (repo `icons/`)
- Scheduled task `Claude Contas - Manutencao` (optional): runs `-Manutencao -Silencioso` at sign-in
  and at the chosen times; updates the tool, rebuilds shortcuts and runs `-Testar` when the Claude
  version changes (result in `contas.json` -> `ultimoTeste`, tray balloon on failure)

For a fresh install driven from chat, follow `PROMPT.md` in the repo (non-interactive
`-Instalar -Sim -Contas ... -Icones ... -Agendar ... -ComSkill -SemEntrar`).

Talk to the user in their language (the maintainer speaks Brazilian Portuguese).
Run commands with PowerShell. Shorthand below: `$cc = "$env:LOCALAPPDATA\ClaudeContas\claude-contas.ps1"`
and run it with `powershell -NoProfile -ExecutionPolicy Bypass -File $cc <args>`.

## Step 1 - check (always)

1. If `$cc` does not exist, install from GitHub:
   `irm https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main/install.ps1 | iex`
   (interactive: it asks for the account name; tell the user to answer in the terminal).
2. Run `-Atualizar` (takes the newest published fix), then `-Diagnostico` and `-Testar`.
   `-Testar` opens a throwaway profile next to the running ones for a few seconds and
   reports whether the app kept it apart (`[user-data-move] stay_chosen_folder` in the
   test profile's `logs\main.log`).
3. Read the tail of `%LOCALAPPDATA%\ClaudeContas\claude-contas.log`.

Decide from the results:

| Result | Meaning | Action |
| --- | --- | --- |
| Test OK, account "deslogada" | session expired or never signed in | `-Entrar <name>` (Step 2) |
| Test OK, account is the SAME as main | signed in with the wrong email | `-Entrar <name>`, sign in with the other email |
| Test OK, shortcuts missing / old v1 shortcuts | shortcuts deleted or left from v1 | `-Reparar` |
| Test OK, but shortcut does nothing | look at claude-contas.log for `abrir ... FALHOU` or an error | fix per log; `-Reparar` |
| Test FAILS | the app changed how it handles the data folder | Step 3 |

## Step 2 - sign in an account

`-Entrar <name>` is interactive (it asks before closing Claude): ask the user to run it
themselves with `! powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ClaudeContas\claude-contas.ps1" -Entrar "<name>"`
or from the Start menu "Claude Contas (menu)" -> E.

Why it exists: Google, email-link and SSO sign-in return to the app through a `claude://`
link. Windows always delivers it to the default instance (account 1). For Google the app
drops a code that its own instance did not start ("Google sign-in code does not answer a
sign-in this app started; ignoring"); a magic link could even sign account 1 into account 2.
The helper closes every Claude window, opens only the target account, catches the
`Claude.exe -- "claude://..."` process Windows starts, kills it and re-sends the link with
`claude-desktop.exe --user-data-dir="<folder>" -- "<link>"`, which the single-instance
lock forwards to the right window. It waits for `claude.ai account active and logged in`
in that profile's log.

## Step 3 - the app changed (test fails)

1. Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools\investigar.ps1` from a clone
   of the repo (find the clone: a folder whose `git remote -v` points to
   `VinguardCP/claude-desktop-multi-account-windows`; otherwise clone it to a temp folder).
   It needs Node.js, copies `app.asar` of the installed version to `%TEMP%`, extracts it with
   `tools\asar-extract.js` and reports the markers below. Read-only.
2. What the method relies on (as of app 6.28899.6, Nov 2026):
   - `index.pre.js`: `chosen: app.commandLine.getSwitchValue("user-data-dir") !== "" && ...`
     -> the userData-move logic keeps the folder we pass (`stay_chosen_folder`).
   - The single-instance lock is taken per userData path, so each folder is its own instance.
   - `CLAUDE_USER_DATA_DIR` is deleted from the environment in signed builds: do not use it.
   - A list of switches makes the app exit ("refusing to start"); `user-data-dir` is not in it.
   - argv rule: nothing may follow a link and only one argument may follow `--`.
   - AppxManifest declares the alias `claude-desktop.exe` and the `claude` protocol.
3. Find what changed: grep the extracted build for `user-data-dir`, `setPath("userData"`,
   `requestSingleInstanceLock`, `stay_chosen_folder`, `refusing to start`. Compare with the
   list above. Reproduce by hand with a temp folder before changing code:
   `Start-Process "$env:LOCALAPPDATA\Microsoft\WindowsApps\claude-desktop.exe" -ArgumentList '--user-data-dir="C:\Temp\cc-test"'`
   then read `C:\Temp\cc-test\logs\main.log` (first lines after `Starting app`).
4. Never kill the user's main Claude window or delete a profile folder without asking.
   Close only test instances (match `--user-data-dir=<test folder>` in the command line;
   the Claude Code CLI is also `claude.exe`, so always filter by path under `WindowsApps`).

## Step 4 - ship the fix

1. Edit `claude-contas.ps1` in the clone. Keep it UTF-8 **with BOM** (Windows PowerShell 5.1
   reads BOM-less files as ANSI and breaks the accents). Keep `install.ps1` pure ASCII and
   without BOM (it runs through `irm | iex`; accents there are `\u00e3` escapes).
2. Bump `$ToolVersion` (semver) and add a line to `CHANGELOG.md`.
3. Check syntax: `[System.Management.Automation.Language.Parser]::ParseFile(...)`, then
   install the local copy with `-Reparar` (run from the clone, it copies itself) and run
   `-Testar` and `-Diagnostico`.
4. Update both READMEs if behaviour or steps changed.
5. Ask the user before committing and pushing. After the push every installed copy picks
   up the new version within a day (daily check on the first shortcut use), or at once with
   `-Atualizar` / by running the install command again.
6. Re-install this skill if `claude-code-skill/claude-contas/SKILL.md` changed: copy it to
   `%USERPROFILE%\.claude\skills\claude-contas\SKILL.md`.
