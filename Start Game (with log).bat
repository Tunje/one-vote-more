@echo off
rem One Vote More - start the game with a console window that shows errors (use this if something goes wrong).

set "GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
set "PROJECT=%~dp0game"

if not exist "%GODOT%" (
  echo Could not find Godot at:
  echo   %GODOT%
  pause
  exit /b 1
)

"%GODOT%" --path "%PROJECT%"
echo.
echo The game has closed. Any errors are shown above.
pause
