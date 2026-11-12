@echo off
rem One Vote More - start the game.
rem Double-click this file. It opens the game with the Godot 4.7.2 engine from your Downloads folder.
rem If Godot moves, change the GODOT line below to the new path of Godot_v4.7.2-stable_win64.exe.

set "GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
set "PROJECT=%~dp0game"

if not exist "%GODOT%" (
  echo Could not find Godot at:
  echo   %GODOT%
  echo Edit Start Game.bat and point GODOT to Godot_v4.7.2-stable_win64.exe.
  pause
  exit /b 1
)

start "" "%GODOT%" --path "%PROJECT%"
