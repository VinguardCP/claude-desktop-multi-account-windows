@echo off
rem Opens a second instance of Claude Desktop using the "Claude-Work" data folder.
rem Replace the program path below with the one from your computer (see README, step 1).
rem The VERSION and CODE parts change whenever the app updates.
start "" "C:\Program Files\WindowsApps\Claude_VERSION_x64__CODE\app\claude.exe" --user-data-dir="%USERPROFILE%\Claude-Work"
