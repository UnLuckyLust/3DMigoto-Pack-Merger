@echo off
setlocal EnableExtensions EnableDelayedExpansion
title 3DMigoto Mod Pack Merger
pushd "%~dp0"
set "ROOT=%CD%"
set "Version=1.0.2"

rem ===================================
rem  USER CONFIG (these can be changed)
rem ===================================
set "CYCLE_NEXT_KEY=VK_ADD"
set "CYCLE_PREV_KEY=VK_SUBTRACT"
rem ==================================

call :init_ansi
call :BANNER

:ASK_NAME
set "DEFAULT_PACK="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -NoLogo -Command ^
  "$root = '%ROOT%'; " ^
  "$rx = '(?im)^\s*;\s*#MOD_PACK_ROOT\s+v[0-9]+\.[0-9]+\.[0-9]+'; " ^
  "$packs = Get-ChildItem -LiteralPath $root -File -Filter '*.ini' -ErrorAction SilentlyContinue | " ^
  "  Where-Object { try { ([IO.File]::ReadAllText($_.FullName) -match $rx) } catch { $false } }; " ^
  "if($packs.Count -eq 1){ [IO.Path]::GetFileNameWithoutExtension($packs[0].Name) }"`) do set "DEFAULT_PACK=%%P"
  
call :TAG INPUT "Enter pack name"
if defined DEFAULT_PACK (
  call :TAG DIM "Found existing pack: '%DEFAULT_PACK%'"
  call :TAG DIM  "Press Enter to use it, or type a name to create a new one"
  echo.
) else (
  call :TAG DIM "Example pack name: RoverPack"
  echo.
)
call :TAG DIM   "available commands:"
call :TAG DIM   "  A  = add mods to the current pack"
call :TAG DIM   "  R  = restore all mods"
call :TAG DIM   "  R1 = restore a single mod"
call :TAG DIM   "  X  = exit"
set "CHAR_NAME="
set /p "CHAR_NAME=> "

for /f "tokens=* delims= " %%A in ("%CHAR_NAME%") do set "CHAR_NAME=%%A"

if /I "%CHAR_NAME%"=="A"  goto ADD
if /I "%CHAR_NAME%"=="R"  goto RESTORE
if /I "%CHAR_NAME%"=="R1" goto RESTORE_ONE
if /I "%CHAR_NAME%"=="X"  goto EOF

if "%CHAR_NAME%"=="" (
  if defined DEFAULT_PACK ( set "CHAR_NAME=%DEFAULT_PACK%"
  ) else ( call :RESTART_MSG WARN "Pack Name cannot be empty^!" )
)

call :DETECT_MODS || exit /b 1

echo.
call :TAG OK "Detected %COUNT% mod folders:"
for /l %%I in (0,1,%END%) do (
  set /a DISP=%%I+1
  call :TAG DIM " !DISP! = !MOD_%%I!"
)

rem ==============================
rem generate pack ini + patch mods
rem ==============================

echo.
call :TAG INPUT "Press any key to generate '%CHAR_NAME%.ini' and patch mods..."
pause >nul
echo.
call :TAG INFO "Merging mods into one pack..."
call :TAG DIM "This may take a bit on large mods"

set "LOG_OUT=%TEMP%\3DMigoto_merge_out.txt"
set "LOG_ERR=%TEMP%\3DMigoto_merge_err.txt"
del "%LOG_OUT%" >nul 2>&1
del "%LOG_ERR%" >nul 2>&1

setlocal DisableDelayedExpansion
powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -Command ^
  "$bat = Get-Content -LiteralPath '%~f0' -Raw; " ^
  "$m = [regex]::Match($bat,'###PS_BEGIN\r?\n(.*?)\r?\n###PS_END','Singleline'); " ^
  "if(-not $m.Success){ throw 'Embedded PS script not found.' } " ^
  "$sb = [scriptblock]::Create($m.Groups[1].Value); " ^
  "& $sb -Root '%ROOT%' -Pack '%CHAR_NAME%' -ModsJoined '%MODS_JOINED%' -NextKey '%CYCLE_NEXT_KEY%' -PrevKey '%CYCLE_PREV_KEY%' -NextPretty '%NEXT_PRETTY%' -PrevPretty '%PREV_PRETTY%' -PackVersion '%Version%'" ^
  1>"%LOG_OUT%" 2>"%LOG_ERR%"
endlocal

set "PSERR=%ERRORLEVEL%"

if not "%PSERR%"=="0" (
  echo.
  call :TAG ERR "Faild to create mod pack"
  call :TAG DIM "Error details saved to: %LOG_ERR%"
  call :WAIT_CLOSE
  exit /b 1
)

echo.
call :TAG OK "Mod pack created successfully"
call :TAG DIM "Put this whole folder in the game Mods folder (keep all subfolders)"
call :WAIT_CLOSE
exit /b 0

rem ==============
rem user functions
rem ==============

:ADD
echo.
call :TAG WARN "ADD MODS: will add missing mod folders into the current pack"

call :DETECT_MODS || exit /b 1

set "PACK_INI="
set "PACK_INI_COUNT=0"

for /f "usebackq delims=" %%F in (`powershell -NoProfile -NoLogo -Command ^
  "$files = Get-ChildItem -LiteralPath '%ROOT%' -Filter *.ini -File | Where-Object { " ^
  "  try { $t = Get-Content -LiteralPath $_.FullName -Raw; " ^
  "        ($t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\s+v[0-9]+\.[0-9]+\.[0-9]+') -and ($t -match '(?im)^\s*\[KeyPackCycle\]\s*$') } catch { $false }" ^
  "}; " ^
  "$files | ForEach-Object { $_.Name }"`) do (
  set /a PACK_INI_COUNT+=1
  if "!PACK_INI_COUNT!"=="1" set "PACK_INI=%%F"
)

if "!PACK_INI_COUNT!"=="0" (
  echo.
  call :TAG ERR "Faild to add mods to pack"
  call :TAG DIM "No generated pack ini (*.ini) was found in this folder"
  echo.
  call :TAG INPUT "Press any key to restart..."
  pause >nul
  goto RESTART
)

if not "!PACK_INI_COUNT!"=="1" (
  echo.
  call :TAG ERR "Faild to add mods to pack"
  call :TAG DIM "More than one generated pack ini was found in this folder:"
  powershell -NoProfile -NoLogo -Command ^
    "Get-ChildItem -LiteralPath '%ROOT%' -Filter *.ini -File | Where-Object { " ^
    "  try { $t = Get-Content -LiteralPath $_.FullName -Raw; " ^
    "        ($t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\s+v[0-9]+\.[0-9]+\.[0-9]+') -and ($t -match '(?im)^\s*\[KeyPackCycle\]\s*$') } catch { $false }" ^
    "} | ForEach-Object { '  - ' + $_.Name }"
  call :TAG DIM "Keep ONLY one pack ini in this folder, then try again."
  echo.
  call :TAG INPUT "Press any key to restart..."
  pause >nul
  goto RESTART
)

goto ADD_HAVE_PACK

:ADD_HAVE_PACK
call :TAG INPUT "Press any key to continue..."
pause >nul

set "LOG_OUT=%TEMP%\3DMigoto_add_out.txt"
set "LOG_ERR=%TEMP%\3DMigoto_add_err.txt"
del "%LOG_OUT%" >nul 2>&1
del "%LOG_ERR%" >nul 2>&1

setlocal DisableDelayedExpansion
powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -Command ^
  "$bat = Get-Content -LiteralPath '%~f0' -Raw; " ^
  "$m = [regex]::Match($bat,'###PS_BEGIN\r?\n(.*?)\r?\n###PS_END','Singleline'); " ^
  "if(-not $m.Success){ throw 'Embedded PS script not found.' } " ^
  "$sb = [scriptblock]::Create($m.Groups[1].Value); " ^
  "& $sb -Root '%ROOT%' -Add -PackIni '%PACK_INI%' -ModsJoined '%MODS_JOINED%' -NextKey '%CYCLE_NEXT_KEY%' -PrevKey '%CYCLE_PREV_KEY%' -NextPretty '%NEXT_PRETTY%' -PrevPretty '%PREV_PRETTY%' -PackVersion '%Version%'" ^
  1>"%LOG_OUT%" 2>"%LOG_ERR%"
endlocal

set "PSERR=%ERRORLEVEL%"

echo.
if not "%PSERR%"=="0" (
  call :TAG ERR "Faild to add mods to pack"
  call :TAG DIM "Error details saved to: %LOG_ERR%"
  echo.
  call :TAG INPUT "Press any key to restart..."
  pause >nul
  goto RESTART
)

call :TAG OK "Add complete"
call :WAIT_CLOSE
exit /b 0

:RESTORE
echo.
call :TAG WARN "RESTORE ALL MODS: will restore *.ini.disabled and delete generated pack ini(s)"

call :DETECT_MODS || exit /b 1

call :TAG INPUT "Press any key to continue..."
pause >nul

set "LOG_OUT=%TEMP%\3DMigoto_restore_out.txt"
set "LOG_ERR=%TEMP%\3DMigoto_restore_err.txt"
del "%LOG_OUT%" >nul 2>&1
del "%LOG_ERR%" >nul 2>&1

echo.
call :TAG INFO "Restoring all mods..."

setlocal DisableDelayedExpansion
powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -Command ^
  "$bat = Get-Content -LiteralPath '%~f0' -Raw; " ^
  "$m = [regex]::Match($bat,'###PS_BEGIN\r?\n(.*?)\r?\n###PS_END','Singleline'); " ^
  "if(-not $m.Success){ throw 'Embedded PS script not found.' } " ^
  "$sb = [scriptblock]::Create($m.Groups[1].Value); " ^
  "& $sb -Root '%ROOT%' -Restore -PackVersion '%Version%'" ^
  1>"%LOG_OUT%" 2>"%LOG_ERR%"
endlocal

set "PSERR=%ERRORLEVEL%"

echo.
if not "%PSERR%"=="0" (
  call :TAG ERR "Faild to restore mods"
  call :TAG DIM "Error details saved to: %LOG_ERR%"
  echo.
  call :TAG INPUT "Press any key to restart..."
  pause >nul
  goto RESTART
)

call :TAG OK "Full restore completed"
call :WAIT_CLOSE
exit /b 0

:RESTORE_ONE
echo.
call :TAG WARN "RESTORE ONE MOD: restore backups only in ONE mod folder + update pack ini"
call :TAG DIM  "NOTE: after restoring, move the mod folder OUT of this pack folder!"

call :DETECT_MODS || exit /b 1

echo.
call :TAG OK "Detected %COUNT% mod folders:"
for /l %%I in (0,1,%END%) do (
  set /a DISP=%%I+1
  call :TAG DIM " !DISP! = !MOD_%%I!"
)

echo.
set "PICK="
set "NONNUM="

if %COUNT% EQU 1 (
  call :TAG WARN "Only one mod detected: !MOD_0!"
  call :TAG INPUT "Remove it? (Y/N)"
  choice /c YN /n >nul
  if errorlevel 2 (
    echo.
    call :TAG WARN "Canceled"
    echo.
    call :TAG INPUT "Press any key to restart..."
    pause >nul
    goto RESTART
  )
  set "PICK=1"
) else (
  call :TAG INPUT "Enter number to remove (1-%COUNT%)"
  set /p "PICK=> "
  for /f "tokens=* delims= " %%A in ("%PICK%") do set "PICK=%%A"

  set "NONNUM="
  for /f "delims=0123456789" %%A in ("!PICK!") do set "NONNUM=%%A"
  if defined NONNUM set "PICK="

  if not "!PICK!"=="" (
    set /a N=!PICK! 2>nul
    if !N! LSS 1 set "PICK="
    if !N! GTR %COUNT% set "PICK="
  )

  if "!PICK!"=="" (
    echo.
    call :TAG ERR "Invalid number (use 1-%COUNT%)"
    echo.
    call :TAG INPUT "Press any key to restart..."
    pause >nul
    goto RESTART
  )
)

set /a IDX=PICK-1
call set "TARGET=%%MOD_!IDX!%%"

echo.
call :TAG WARN "Restoring mod: '%TARGET%'"
call :TAG INPUT "Press any key to continue..."
pause >nul

set "LOG_OUT=%TEMP%\3DMigoto_restore1_out.txt"
set "LOG_ERR=%TEMP%\3DMigoto_restore1_err.txt"
del "%LOG_OUT%" >nul 2>&1
del "%LOG_ERR%" >nul 2>&1

echo.
call :TAG INFO "Restoring mod: '%TARGET%'..."

setlocal DisableDelayedExpansion
powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -Command ^
  "$bat = Get-Content -LiteralPath '%~f0' -Raw; " ^
  "$m = [regex]::Match($bat,'###PS_BEGIN\r?\n(.*?)\r?\n###PS_END','Singleline'); " ^
  "if(-not $m.Success){ throw 'Embedded PS script not found.' } " ^
  "$sb = [scriptblock]::Create($m.Groups[1].Value); " ^
  "& $sb -Root '%ROOT%' -RestoreOne -ModFolder '%TARGET%' -PackVersion '%Version%'" ^
  1>"%LOG_OUT%" 2>"%LOG_ERR%"
endlocal

set "PSERR=%ERRORLEVEL%"

echo.
if not "%PSERR%"=="0" (
  call :TAG ERR "Faild to restore mod: '%TARGET%'"
  call :TAG DIM "Make sure there is .ini.disabled file in the mod folder / mod exists in the pack"
  call :TAG DIM "Error details saved to: %LOG_ERR%"
  echo.
  call :TAG INPUT "Press any key to restart..."
  pause >nul
  goto RESTART
)

call :TAG OK "Restored mod: '%TARGET%'"
call :TAG WARN "IMPORTANT: You can now move the '%TARGET%' folder OUT of this pack folder"
call :TAG DIM  "If you leave it here, it will conflict with the pack ini!"
call :WAIT_CLOSE
exit /b 0

rem =======
rem helpers
rem =======

:DETECT_MODS
for /f "delims=" %%V in ('set MOD_ 2^>nul') do set "%%V="

set /a COUNT=0
for /d %%D in (*) do (
  if exist "%%D\*.ini" (
    set "MOD_!COUNT!=%%~nxD"
    set /a COUNT+=1
  )
)

if %COUNT% LSS 1 (
  set "END=0"
  set "MODS_JOINED="

  echo.
  call :TAG ERR "No mod folders found"
  call :TAG DIM "Put this BAT in a folder that contains 1+ mod folders"
  call :TAG DIM "Each mod folder must contain:"
  call :TAG DIM "  - one .ini file (mod.ini or similar)"
  call :TAG DIM "  - a Meshes and/or Textures folder"
  call :WAIT_CLOSE
  exit /b 1
)

set /a END=COUNT-1

set "MODS_JOINED="
for /l %%I in (0,1,%END%) do (
  if defined MOD_%%I (
    if defined MODS_JOINED (
      set "MODS_JOINED=!MODS_JOINED!;;!MOD_%%I!"
    ) else (
      set "MODS_JOINED=!MOD_%%I!"
    )
  )
)
exit /b 0

:RESTART_MSG
set "RESTART_TYPE=%~1"
set "RESTART_TEXT=%~2"
goto RESTART

:RESTART
cls
call :BANNER
if defined RESTART_TYPE (
  setlocal DisableDelayedExpansion
  call :TAG "%RESTART_TYPE%" "%RESTART_TEXT%"
  echo.
  endlocal
  set "RESTART_TYPE="
  set "RESTART_TEXT="
)
goto ASK_NAME

:WAIT_CLOSE
echo.
call :TAG INPUT "Press any key to close..."
pause >nul
exit /b 0

:BANNER
call :vk_pretty "%CYCLE_NEXT_KEY%" NEXT_PRETTY
call :vk_pretty "%CYCLE_PREV_KEY%" PREV_PRETTY

call :TAG DIM "===================================================="
call :TAG DIM "       3DMigoto Mod Pack Merger by UnLuckyLust"
call :TAG DIM "                 version %Version%"
echo.
call :TAG DIM "Use !NEXT_PRETTY! or !PREV_PRETTY! to cycle mods while in-game"
call :TAG DIM "       (cycle keys can be changed in config)"
call :TAG DIM "===================================================="
echo.
exit /b 0

:init_ansi
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
exit /b 0

:TAG
setlocal DisableDelayedExpansion
set "TYPE=%~1"
set "MSG=%~2"
set "C=%ESC%[97m"
if /I "%TYPE%"=="INPUT" set "C=%ESC%[96m"
if /I "%TYPE%"=="OK" set "C=%ESC%[92m"
if /I "%TYPE%"=="WARN" set "C=%ESC%[93m"
if /I "%TYPE%"=="ERR" set "C=%ESC%[91m"
if /I "%TYPE%"=="INFO" set "C=%ESC%[95m"
if /I "%TYPE%"=="DIM" set "C=%ESC%[90m"
echo(%C%%MSG%%ESC%[0m
endlocal
exit /b 0

:vk_pretty
setlocal EnableDelayedExpansion
set "K=%~1"
set "OUT=%~2"

for %%Z in ("!K!") do set "K=%%~Z"
set "K=!K:"=!"

set "PRETTY="

rem =====================
rem  ARROWS / NAVIGATION
rem =====================
if /I "!K!"=="VK_LEFT"      set "PRETTY=Left Arrow"
if /I "!K!"=="VK_RIGHT"     set "PRETTY=Right Arrow"
if /I "!K!"=="VK_UP"        set "PRETTY=Up Arrow"
if /I "!K!"=="VK_DOWN"      set "PRETTY=Down Arrow"
if /I "!K!"=="VK_HOME"      set "PRETTY=Home"
if /I "!K!"=="VK_END"       set "PRETTY=End"
if /I "!K!"=="VK_PRIOR"     set "PRETTY=Page Up"
if /I "!K!"=="VK_NEXT"      set "PRETTY=Page Down"
if /I "!K!"=="VK_INSERT"    set "PRETTY=Insert"
if /I "!K!"=="VK_DELETE"    set "PRETTY=Delete"

rem =================
rem  BASIC / EDITING
rem =================
if /I "!K!"=="VK_RETURN"    set "PRETTY=Enter"
if /I "!K!"=="VK_ESCAPE"    set "PRETTY=Esc"
if /I "!K!"=="VK_TAB"       set "PRETTY=Tab"
if /I "!K!"=="VK_SPACE"     set "PRETTY=Space"
if /I "!K!"=="VK_BACK"      set "PRETTY=Backspace"
if /I "!K!"=="VK_CLEAR"     set "PRETTY=Clear"
if /I "!K!"=="VK_PAUSE"     set "PRETTY=Pause"
if /I "!K!"=="VK_CANCEL"    set "PRETTY=Cancel"

rem ===========
rem  LOCK KEYS
rem ===========
if /I "!K!"=="VK_CAPITAL"   set "PRETTY=Caps Lock"
if /I "!K!"=="VK_NUMLOCK"   set "PRETTY=Num Lock"
if /I "!K!"=="VK_SCROLL"    set "PRETTY=Scroll Lock"

rem ===========
rem  MODIFIERS
rem ===========
if /I "!K!"=="VK_SHIFT"     set "PRETTY=Shift"
if /I "!K!"=="VK_CONTROL"   set "PRETTY=Ctrl"
if /I "!K!"=="VK_MENU"      set "PRETTY=Alt"
if /I "!K!"=="VK_LSHIFT"    set "PRETTY=Left Shift"
if /I "!K!"=="VK_RSHIFT"    set "PRETTY=Right Shift"
if /I "!K!"=="VK_LCONTROL"  set "PRETTY=Left Ctrl"
if /I "!K!"=="VK_RCONTROL"  set "PRETTY=Right Ctrl"
if /I "!K!"=="VK_LMENU"     set "PRETTY=Left Alt"
if /I "!K!"=="VK_RMENU"     set "PRETTY=Right Alt"

rem ==================
rem  WINDOWS / SYSTEM
rem ==================
if /I "!K!"=="VK_LWIN"      set "PRETTY=Left Win"
if /I "!K!"=="VK_RWIN"      set "PRETTY=Right Win"
if /I "!K!"=="VK_APPS"      set "PRETTY=Menu Key"
if /I "!K!"=="VK_SLEEP"     set "PRETTY=Sleep"

rem ==================
rem  PRINT / SNAPSHOT
rem ==================
if /I "!K!"=="VK_SNAPSHOT"  set "PRETTY=Print Screen"
if /I "!K!"=="VK_PRINT"     set "PRETTY=Print"
if /I "!K!"=="VK_EXECUTE"   set "PRETTY=Execute"
if /I "!K!"=="VK_HELP"      set "PRETTY=Help"
if /I "!K!"=="VK_SELECT"    set "PRETTY=Select"

rem ========================
rem  FUNCTION KEYS (F1-F24)
rem ========================
if /I "!K!"=="VK_F1"  set "PRETTY=F1"
if /I "!K!"=="VK_F2"  set "PRETTY=F2"
if /I "!K!"=="VK_F3"  set "PRETTY=F3"
if /I "!K!"=="VK_F4"  set "PRETTY=F4"
if /I "!K!"=="VK_F5"  set "PRETTY=F5"
if /I "!K!"=="VK_F6"  set "PRETTY=F6"
if /I "!K!"=="VK_F7"  set "PRETTY=F7"
if /I "!K!"=="VK_F8"  set "PRETTY=F8"
if /I "!K!"=="VK_F9"  set "PRETTY=F9"
if /I "!K!"=="VK_F10" set "PRETTY=F10"
if /I "!K!"=="VK_F11" set "PRETTY=F11"
if /I "!K!"=="VK_F12" set "PRETTY=F12"
if /I "!K!"=="VK_F13" set "PRETTY=F13"
if /I "!K!"=="VK_F14" set "PRETTY=F14"
if /I "!K!"=="VK_F15" set "PRETTY=F15"
if /I "!K!"=="VK_F16" set "PRETTY=F16"
if /I "!K!"=="VK_F17" set "PRETTY=F17"
if /I "!K!"=="VK_F18" set "PRETTY=F18"
if /I "!K!"=="VK_F19" set "PRETTY=F19"
if /I "!K!"=="VK_F20" set "PRETTY=F20"
if /I "!K!"=="VK_F21" set "PRETTY=F21"
if /I "!K!"=="VK_F22" set "PRETTY=F22"
if /I "!K!"=="VK_F23" set "PRETTY=F23"
if /I "!K!"=="VK_F24" set "PRETTY=F24"

rem ========
rem  NUMPAD
rem ========
if /I "!K!"=="VK_NUMPAD0"    set "PRETTY=Numpad 0"
if /I "!K!"=="VK_NUMPAD1"    set "PRETTY=Numpad 1"
if /I "!K!"=="VK_NUMPAD2"    set "PRETTY=Numpad 2"
if /I "!K!"=="VK_NUMPAD3"    set "PRETTY=Numpad 3"
if /I "!K!"=="VK_NUMPAD4"    set "PRETTY=Numpad 4"
if /I "!K!"=="VK_NUMPAD5"    set "PRETTY=Numpad 5"
if /I "!K!"=="VK_NUMPAD6"    set "PRETTY=Numpad 6"
if /I "!K!"=="VK_NUMPAD7"    set "PRETTY=Numpad 7"
if /I "!K!"=="VK_NUMPAD8"    set "PRETTY=Numpad 8"
if /I "!K!"=="VK_NUMPAD9"    set "PRETTY=Numpad 9"
if /I "!K!"=="VK_ADD"        set "PRETTY=Numpad +"
if /I "!K!"=="VK_SUBTRACT"   set "PRETTY=Numpad -"
if /I "!K!"=="VK_MULTIPLY"   set "PRETTY=Numpad *"
if /I "!K!"=="VK_DIVIDE"     set "PRETTY=Numpad /"
if /I "!K!"=="VK_DECIMAL"    set "PRETTY=Numpad ."
if /I "!K!"=="VK_SEPARATOR"  set "PRETTY=Numpad Separator"

rem ================
rem  MEDIA / VOLUME
rem ================
if /I "!K!"=="VK_VOLUME_MUTE"         set "PRETTY=Volume Mute"
if /I "!K!"=="VK_VOLUME_DOWN"         set "PRETTY=Volume Down"
if /I "!K!"=="VK_VOLUME_UP"           set "PRETTY=Volume Up"
if /I "!K!"=="VK_MEDIA_NEXT_TRACK"    set "PRETTY=Media Next"
if /I "!K!"=="VK_MEDIA_PREV_TRACK"    set "PRETTY=Media Prev"
if /I "!K!"=="VK_MEDIA_STOP"          set "PRETTY=Media Stop"
if /I "!K!"=="VK_MEDIA_PLAY_PAUSE"    set "PRETTY=Play/Pause"

rem ==============
rem  BROWSER KEYS
rem ==============
if /I "!K!"=="VK_BROWSER_BACK"        set "PRETTY=Browser Back"
if /I "!K!"=="VK_BROWSER_FORWARD"     set "PRETTY=Browser Forward"
if /I "!K!"=="VK_BROWSER_REFRESH"     set "PRETTY=Browser Refresh"
if /I "!K!"=="VK_BROWSER_STOP"        set "PRETTY=Browser Stop"
if /I "!K!"=="VK_BROWSER_SEARCH"      set "PRETTY=Browser Search"
if /I "!K!"=="VK_BROWSER_FAVORITES"   set "PRETTY=Browser Favorites"
if /I "!K!"=="VK_BROWSER_HOME"        set "PRETTY=Browser Home"

rem =============
rem  LAUNCH KEYS
rem =============
if /I "!K!"=="VK_LAUNCH_MAIL"         set "PRETTY=Launch Mail"
if /I "!K!"=="VK_LAUNCH_MEDIA_SELECT" set "PRETTY=Launch Media"
if /I "!K!"=="VK_LAUNCH_APP1"         set "PRETTY=Launch App1"
if /I "!K!"=="VK_LAUNCH_APP2"         set "PRETTY=Launch App2"

rem ===================
rem  OEM / PUNCTUATION
rem ===================
if /I "!K!"=="VK_OEM_PLUS"    set "PRETTY=="
if /I "!K!"=="VK_OEM_MINUS"   set "PRETTY=-"
if /I "!K!"=="VK_OEM_COMMA"   set "PRETTY=,"
if /I "!K!"=="VK_OEM_PERIOD"  set "PRETTY=."
if /I "!K!"=="VK_OEM_1"       set "PRETTY=;"
if /I "!K!"=="VK_OEM_2"       set "PRETTY=/"
if /I "!K!"=="VK_OEM_3"       set "PRETTY=`"
if /I "!K!"=="VK_OEM_4"       set "PRETTY=["
if /I "!K!"=="VK_OEM_5"       set "PRETTY=\"
if /I "!K!"=="VK_OEM_6"       set "PRETTY=]"
if /I "!K!"=="VK_OEM_7"       set "PRETTY='"
if /I "!K!"=="VK_OEM_8"       set "PRETTY=OEM 8"
if /I "!K!"=="VK_OEM_102"     set "PRETTY=OEM 102"
if /I "!K!"=="VK_OEM_CLEAR"   set "PRETTY=OEM Clear"

rem =====================================
rem  DIGITS (IF SOMEONE USES VK_0..VK_9)
rem =====================================
if /I "!K!"=="VK_0" set "PRETTY=0"
if /I "!K!"=="VK_1" set "PRETTY=1"
if /I "!K!"=="VK_2" set "PRETTY=2"
if /I "!K!"=="VK_3" set "PRETTY=3"
if /I "!K!"=="VK_4" set "PRETTY=4"
if /I "!K!"=="VK_5" set "PRETTY=5"
if /I "!K!"=="VK_6" set "PRETTY=6"
if /I "!K!"=="VK_7" set "PRETTY=7"
if /I "!K!"=="VK_8" set "PRETTY=8"
if /I "!K!"=="VK_9" set "PRETTY=9"

rem ======================================
rem  LETTERS (IF SOMEONE USES VK_A..VK_Z)
rem ======================================
if /I "!K!"=="VK_A" set "PRETTY=A"
if /I "!K!"=="VK_B" set "PRETTY=B"
if /I "!K!"=="VK_C" set "PRETTY=C"
if /I "!K!"=="VK_D" set "PRETTY=D"
if /I "!K!"=="VK_E" set "PRETTY=E"
if /I "!K!"=="VK_F" set "PRETTY=F"
if /I "!K!"=="VK_G" set "PRETTY=G"
if /I "!K!"=="VK_H" set "PRETTY=H"
if /I "!K!"=="VK_I" set "PRETTY=I"
if /I "!K!"=="VK_J" set "PRETTY=J"
if /I "!K!"=="VK_K" set "PRETTY=K"
if /I "!K!"=="VK_L" set "PRETTY=L"
if /I "!K!"=="VK_M" set "PRETTY=M"
if /I "!K!"=="VK_N" set "PRETTY=N"
if /I "!K!"=="VK_O" set "PRETTY=O"
if /I "!K!"=="VK_P" set "PRETTY=P"
if /I "!K!"=="VK_Q" set "PRETTY=Q"
if /I "!K!"=="VK_R" set "PRETTY=R"
if /I "!K!"=="VK_S" set "PRETTY=S"
if /I "!K!"=="VK_T" set "PRETTY=T"
if /I "!K!"=="VK_U" set "PRETTY=U"
if /I "!K!"=="VK_V" set "PRETTY=V"
if /I "!K!"=="VK_W" set "PRETTY=W"
if /I "!K!"=="VK_X" set "PRETTY=X"
if /I "!K!"=="VK_Y" set "PRETTY=Y"
if /I "!K!"=="VK_Z" set "PRETTY=Z"

if defined PRETTY (
  endlocal & set "%OUT%=%PRETTY%" & exit /b 0
)

set "S=!K!"
if /I "!S:~0,3!"=="VK_" set "S=!S:~3!"
set "S=!S:_= !"

endlocal & set "%OUT%=%S%" & exit /b 0

rem ==================
rem PowerShell payload
rem ==================

###PS_BEGIN
param(
  [string]$Root,
  [string]$PackIni,
  [string]$PackVersion,
  [string]$Pack,
  [string]$ModsJoined,

  [switch]$Restore,
  [switch]$Add,

  [switch]$RestoreOne,
  [string]$ModFolder,

  [string]$NextKey,
  [string]$PrevKey,
  [string]$NextPretty,
  [string]$PrevPretty
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Root).Path
if(Test-Path -LiteralPath $root -PathType Leaf){
  $root = Split-Path -LiteralPath $root -Parent
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$swapvar = "swapvar"

function Sanitize([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return "Pack" }
  ($s -replace '\s+','' -replace '[^A-Za-z0-9_\-]','')
}

if([string]::IsNullOrWhiteSpace($PackVersion)){ $PackVersion = "0.0.0" }
if([string]::IsNullOrWhiteSpace($NextKey)){ $NextKey = 'VK_RIGHT' }
if([string]::IsNullOrWhiteSpace($PrevKey)){ $PrevKey = 'VK_LEFT' }
if([string]::IsNullOrWhiteSpace($NextPretty)){ $NextPretty = $NextKey }
if([string]::IsNullOrWhiteSpace($PrevPretty)){ $PrevPretty = $PrevKey }

if($RestoreOne -and [string]::IsNullOrWhiteSpace($ModFolder)){
  throw "ModFolder is required for RestoreOne."
}

# --------
# helpers
# --------

function IsGeneratedPackIni([string]$path){
  try{
    $t = [System.IO.File]::ReadAllText($path)
    return ($t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\s+v[0-9]+\.[0-9]+\.[0-9]+') -and
           ($t -match '(?im)^\s*\[KeyPackCycle\]\s*$')
  } catch { return $false }
}

function GetSinglePackIniInRoot(){
  $candidates = Get-ChildItem -LiteralPath $root -File -Filter "*.ini" -ErrorAction SilentlyContinue |
    Where-Object { IsGeneratedPackIni $_.FullName }
  if(-not $candidates -or $candidates.Count -eq 0){ throw "No generated pack ini found in root." }
  if($candidates.Count -gt 1){
    $names = ($candidates | ForEach-Object { $_.Name }) -join ", "
    throw "Multiple pack ini files found in root: $names"
  }
  return $candidates[0]
}

function ParsePackMods([string]$packPath){
  $t = [System.IO.File]::ReadAllText($packPath).Replace("`r`n","`n").Replace("`r","`n")
  $lines = $t -split "`n"

  $ns = $null
  foreach($l in $lines){
    if($l -match '^\s*namespace\s*=\s*(.+?)\\Master\s*$'){ $ns = $matches[1].Trim(); break }
  }
  if(-not $ns){ throw "Pack ini missing namespace = X\Master" }

  $nk = $null; $pk = $null
  for($i=0;$i -lt $lines.Count;$i++){
    if($lines[$i].Trim() -ieq "[KeyPackCycle]"){
      for($j=$i+1;$j -lt [Math]::Min($i+12,$lines.Count);$j++){
        if($lines[$j] -match '^\s*key\s*=\s*(.+?)\s*$'){  $nk = $matches[1].Trim(); continue }
        if($lines[$j] -match '^\s*back\s*=\s*(.+?)\s*$'){ $pk = $matches[1].Trim(); continue }
        if($lines[$j].Trim().StartsWith("[")) { break }
      }
      break
    }
  }

  $mods = New-Object System.Collections.Generic.List[object]
  foreach($l in $lines){
    if($l -match '^\s*;\s*(\d+)\s*=\s*(.+?)\s*$'){
      $idx = [int]$matches[1]
      $name = $matches[2].Trim()
      if($idx -ge 1 -and $name){
        $mods.Add([pscustomobject]@{ Index=$idx; Name=$name })
      }
    }
  }

  [pscustomobject]@{
    Namespace = $ns
    NextKey   = $nk
    PrevKey   = $pk
    Mods      = $mods
  }
}

function IsPackRootIni([string]$path){
  try{
    $t = [System.IO.File]::ReadAllText($path)
    return ($t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\s+v[0-9]+\.[0-9]+\.[0-9]+')
  } catch { return $false }
}

function CleanupOldPackRootInis([string]$keepFullPath){
  $keepFullPath = [System.IO.Path]::GetFullPath($keepFullPath)

  $deleted = New-Object System.Collections.Generic.List[string]

  $candidates = Get-ChildItem -LiteralPath $root -File -Filter "*.ini" -ErrorAction SilentlyContinue |
    Where-Object { IsPackRootIni $_.FullName }

  foreach($f in $candidates){
    $full = [System.IO.Path]::GetFullPath($f.FullName)
    if($full -ieq $keepFullPath){ continue }
    try{
      Remove-Item -LiteralPath $full -Force
      $deleted.Add($f.Name)
    } catch {
      throw "Failed to delete old pack ini '$($f.Name)': $($_.Exception.Message)"
    }
  }

  return $deleted
}

function WritePackIni([string]$packPath, [string]$packNs, [object[]]$mods, [string]$nk, [string]$pk){
  if([string]::IsNullOrWhiteSpace($nk)){ $nk = $NextKey }
  if([string]::IsNullOrWhiteSpace($pk)){ $pk = $PrevKey }

  $cycle = @("0") + ($mods | Sort-Object Index | ForEach-Object { [string]$_.Index })

  $L = New-Object System.Collections.Generic.List[string]
  $L.Add("; " + ([System.IO.Path]::GetFileNameWithoutExtension($packPath)) + " Mod Pack")
  $L.Add("; Use " + $NextPretty + " or " + $PrevPretty + " to cycle mods")
  $L.Add(";")
  $L.Add("; Total mods in this pack: " + $mods.Count)
  $L.Add(";    0 = Vanilla (no mod)")
  foreach($m in ($mods | Sort-Object Index)){
    $L.Add(";    " + $m.Index + " = " + $m.Name)
  }
  $L.Add(";")
  $L.Add("; Generated with 3DMigoto Mod Pack Merger by UnLuckyLust")
  $L.Add("; ==========================================================")
  $L.Add("")
  $L.Add("namespace = " + $packNs + "\Master")
  $L.Add("")
  $L.Add("[Constants]")
  $L.Add("global persist $" + $swapvar + " = 0")
  $L.Add("")
  $L.Add("[KeyPackCycle]")
  $L.Add("key = " + $nk)
  $L.Add("back = " + $pk)
  $L.Add("type = cycle")
  $L.Add("$" + $swapvar + " = " + ($cycle -join ","))
  $L.Add("")
  $L.Add("; ==========================================================")
  $L.Add("; IMPORTANT: Do not DELETE or MODIFY the line below!")
  $L.Add("; #MOD_PACK_ROOT v$PackVersion by UnLuckyLust")

  [System.IO.File]::WriteAllText($packPath, ($L -join "`n"), $utf8NoBom)
}

function GetNextFreeIndex([object[]]$mods){
  $used = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach($m in $mods){
    if($null -ne $m.Index){ [void]$used.Add([int]$m.Index) }
  }

  $i = 1
  while($used.Contains($i)){ $i++ }
  return $i
}

# -----------
# patch INIs
# -----------

$rxSection = [regex]::new('^\s*\[(?<name>[^\]]+)\]\s*$', 'Compiled')
$rxHash = [regex]::new('^\s*hash\s*=', 'IgnoreCase,Compiled')
$rxMatchPr = [regex]::new('^\s*match_priority\s*=', 'IgnoreCase,Compiled')
$rxNsLine = [regex]::new('^\s*namespace\s*=', 'IgnoreCase,Compiled')

function Patch-Ini([string]$iniPath, [string]$packNs, [string]$modNs, [int]$idx){
  if([string]::IsNullOrWhiteSpace($iniPath)){
    throw "Patch-Ini called with empty iniPath (idx=$idx, packNs=$packNs, modNs=$modNs)"
  }
  if(-not (Test-Path -LiteralPath $iniPath -PathType Leaf)){
    throw "INI file not found: $iniPath"
  }

  $bak = $iniPath + ".disabled"
  if(Test-Path -LiteralPath $bak){
    $text = [System.IO.File]::ReadAllText($bak)
  } else {
    $text = [System.IO.File]::ReadAllText($iniPath)
    [System.IO.File]::WriteAllText($bak, $text, $utf8NoBom)
  }

  $text  = $text.Replace("`r`n","`n").Replace("`r","`n")
  $lines = $text -split "`n"
  $out   = New-Object System.Collections.Generic.List[string]

  $hasNs = $false
  foreach($l in $lines){
    if($rxNsLine.IsMatch($l)){ $hasNs = $true; break }
  }
  if(-not $hasNs){
    $out.Add('namespace = ' + $packNs + '\' + $modNs)
    $out.Add('')
  }

  $isOverride = $false
  $armed      = $false
  $didIf      = $false

  $ifLine = "if `$" + $packNs + "\Master\$$swapvar == $idx"

  foreach($line in $lines){
    $m = $rxSection.Match($line)
    if($m.Success){
      if($didIf){
        $out.Add('endif')
        $out.Add('')
        $didIf = $false
      }

      $sectionName = $m.Groups["name"].Value
      $isOverride =
        $sectionName.StartsWith("TextureOverride", [System.StringComparison]::OrdinalIgnoreCase) -or
        $sectionName.StartsWith("ShaderOverride",  [System.StringComparison]::OrdinalIgnoreCase)

      $armed = $isOverride
      $out.Add($line)
      continue
    }

    if($isOverride -and $rxMatchPr.IsMatch($line)){ continue }

    if($isOverride -and $armed -and $rxHash.IsMatch($line)){
      $out.Add($line)
      $out.Add('match_priority = ' + $idx)
      $out.Add($ifLine)
      $didIf = $true
      $armed = $false
      continue
    }

    if($didIf){
      $trim = $line.Trim()
      if($trim.StartsWith(";") -or $trim -eq ""){
        $out.Add($line)
      } else {
        $out.Add("`t" + $line)
      }
      continue
    }

    $out.Add($line)
  }

  if($didIf){
    $out.Add('endif')
    $out.Add('')
  }

  $final = ($out -join "`n").TrimEnd() + "`n"
  [System.IO.File]::WriteAllText($iniPath, $final, $utf8NoBom)
}

function Patch-ModFolder([string]$folder, [string]$packNs, [int]$idx){
  $modDir = Join-Path $root $folder
  if(-not (Test-Path -LiteralPath $modDir -PathType Container)){
    throw "Missing folder: $folder (resolved: $modDir)"
  }

  $modNs = Sanitize $folder

  $dirs = Get-ChildItem -LiteralPath $modDir -Directory -Recurse -Force -ErrorAction Stop |
    Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }

  $dirs = @((Get-Item -LiteralPath $modDir)) + $dirs
  $dirs = $dirs | Sort-Object FullName -Unique

  $inis = @(
    foreach($d in $dirs){
      Get-ChildItem -LiteralPath $d.FullName -File -Filter "*.ini" -Force -ErrorAction SilentlyContinue
    }
  ) | Where-Object {
    $_ -and $_.FullName -and
    $_.FullName -notmatch '(?i)\.ini\.disabled$' -and
    $_.Name -notmatch '(?i)^DISABLED'
  }

  if(-not $inis -or $inis.Count -eq 0){
    throw "No .ini files found to patch in: $modDir"
  }

  foreach($ini in $inis){
    Patch-Ini $ini.FullName $packNs $modNs $idx
  }
}

function Renumber-And-RepatchMods([object]$info){
  $sorted = @($info.Mods | Sort-Object Index)

  $new = New-Object System.Collections.Generic.List[object]
  $i = 1
  foreach($m in $sorted){
    Patch-ModFolder $m.Name $info.Namespace $i
    $new.Add([pscustomobject]@{ Index=$i; Name=$m.Name })
    $i++
  }

  $info.Mods = $new

  $packFile = GetSinglePackIniInRoot
  WritePackIni $packFile.FullName $info.Namespace $info.Mods $info.NextKey $info.PrevKey
}

# ----------------
# restore all mods
# ----------------

function Get-SafeDirs([string]$base){
  $baseItem = Get-Item -LiteralPath $base -ErrorAction Stop

  $dirs = Get-ChildItem -LiteralPath $base -Directory -Recurse -Force -ErrorAction Stop |
    Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }

  $dirs = @($baseItem) + $dirs
  $dirs | Sort-Object FullName -Unique
}

function Restore-All {
  $restored = 0

  $dirs = Get-SafeDirs $root

  $disabledFiles = @(
    foreach($d in $dirs){
      Get-ChildItem -LiteralPath $d.FullName -File -Filter "*.ini.disabled" -Force -ErrorAction SilentlyContinue
    }
  )

  foreach($f in $disabledFiles){
    if(-not $f -or -not $f.FullName){ continue }
    $orig = $f.FullName.Substring(0, $f.FullName.Length - ".disabled".Length)

    if(Test-Path -LiteralPath $orig){ Remove-Item -LiteralPath $orig -Force }
    Move-Item -LiteralPath $f.FullName -Destination $orig -Force
    $restored++
  }

  $legacyFiles = @(
    foreach($d in $dirs){
      Get-ChildItem -LiteralPath $d.FullName -File -Filter "DISABLED*.ini" -Force -ErrorAction SilentlyContinue
    }
  )

  foreach($b in $legacyFiles){
    if(-not $b -or -not $b.FullName){ continue }
    $origName = $b.Name.Substring("DISABLED".Length)
    $origPath = Join-Path $b.DirectoryName $origName
    Copy-Item -LiteralPath $b.FullName -Destination $origPath -Force
    Remove-Item -LiteralPath $b.FullName -Force
    $restored++
  }

  $rootInis = Get-ChildItem -LiteralPath $root -File -Filter "*.ini" -Force -ErrorAction SilentlyContinue
  $deleted = 0
  foreach($ini in $rootInis){
    $t = Get-Content -LiteralPath $ini.FullName -Raw -ErrorAction SilentlyContinue
    if($t -and $t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\s+v[0-9]+\.[0-9]+\.[0-9]+'){
      Remove-Item -LiteralPath $ini.FullName -Force
      $deleted++
    }
  }

  if($restored -le 0){
    throw "No backup files found to restore."
  }

  Write-Host "OK: Restored $restored file(s) + removed $deleted generated pack INI(s)"
}

if($Restore){
  Restore-All
  return
}

# ---------------
# Restore one mod
# ---------------

if($RestoreOne){
  $packFile = GetSinglePackIniInRoot
  $info = ParsePackMods $packFile.FullName
  $PackNs = $info.Namespace

  $target = $null
  foreach($m in $info.Mods){
    if($m.Name -ieq $ModFolder){ $target = $m; break }
  }
  if(-not $target){
    throw "Mod '$ModFolder' not found in pack ini list. (Pack: $($packFile.Name))"
  }

  $modDir = Join-Path $root $target.Name
  if(-not (Test-Path -LiteralPath $modDir -PathType Container)){
    throw "Folder not found: $ModFolder"
  }

  $restored = 0

  $dirs = Get-SafeDirs $modDir

  $disabledFiles = @(
    foreach($d in $dirs){
      Get-ChildItem -LiteralPath $d.FullName -File -Filter "*.ini.disabled" -Force -ErrorAction SilentlyContinue
    }
  )

  foreach($f in $disabledFiles){
    if(-not $f -or -not $f.FullName){ continue }
    $orig = $f.FullName.Substring(0, $f.FullName.Length - ".disabled".Length)

    if(Test-Path -LiteralPath $orig){ Remove-Item -LiteralPath $orig -Force }
    Move-Item -LiteralPath $f.FullName -Destination $orig -Force
    $restored++
  }

  $legacyFiles = @(
    foreach($d in $dirs){
      Get-ChildItem -LiteralPath $d.FullName -File -Filter "DISABLED*.ini" -Force -ErrorAction SilentlyContinue
    }
  )

  foreach($b in $legacyFiles){
    if(-not $b -or -not $b.FullName){ continue }
    $origName = $b.Name.Substring("DISABLED".Length)
    $origPath = Join-Path $b.DirectoryName $origName
    Copy-Item -LiteralPath $b.FullName -Destination $origPath -Force
    Remove-Item -LiteralPath $b.FullName -Force
    $restored++
  }

  if($restored -le 0){
    throw "No backup files found in '$ModFolder' to restore."
  }

  $remaining = @()
  foreach($m in $info.Mods){
    if($m.Name -ine $ModFolder){ $remaining += $m }
  }
  $info.Mods = $remaining

  Renumber-And-RepatchMods $info

  Write-Host "OK: Restored $restored file(s) in mod folder '$ModFolder'"
  Write-Host "OK: Removed '$ModFolder' and renumbered remaining mods to 1..$($info.Mods.Count)"
  return
}

# ----------------
# Add missing mods
# ----------------

if($Add){
  if([string]::IsNullOrWhiteSpace($PackIni)){
    $packFile = GetSinglePackIniInRoot
  } else {
    $packPath = Join-Path $root $PackIni
    if(-not (Test-Path -LiteralPath $packPath -PathType Leaf)){
      throw "Pack ini not found: $PackIni"
    }
    if(-not (IsGeneratedPackIni $packPath)){
      throw "Provided pack ini is not a generated pack ini: $PackIni"
    }
    $packFile = Get-Item -LiteralPath $packPath
  }

  $info = ParsePackMods $packFile.FullName
  $packNs = $info.Namespace

  $Detected = @($ModsJoined -split ';;' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
  $Detected = $Detected | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) -PathType Container }

  if(-not $Detected -or $Detected.Count -lt 1){
    throw "No mod folders found to add."
  }

  $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach($m in $info.Mods){ [void]$set.Add($m.Name) }

  $missing = New-Object System.Collections.Generic.List[string]
  foreach($f in $Detected){
    if(-not $set.Contains($f)){ $missing.Add($f) }
  }

  if($missing.Count -eq 0){
    Write-Host "OK: No missing mods to add."
    return
  }

  foreach($folder in $missing){
    $idx = GetNextFreeIndex $info.Mods

    Patch-ModFolder $folder $packNs $idx
    $info.Mods.Add([pscustomobject]@{ Index=$idx; Name=$folder })
  }

  WritePackIni $packFile.FullName $packNs $info.Mods $info.NextKey $info.PrevKey
  Write-Output "OK: Added $($missing.Count) mod folder(s): $($missing -join ', ')"
  return
}

# --------------
# Create new pack
# --------------

$PackNs = Sanitize $Pack
$Mods = @($ModsJoined -split ';;' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if($Mods.Count -lt 1){ throw "Need at least 1 valid mod folder." }

$master = New-Object System.Collections.Generic.List[string]
$master.Add("; $PackNs Mod Pack")
$master.Add("; Use " + $NextPretty + " or " + $PrevPretty + " to cycle mods")
$master.Add(";")
$master.Add("; Total mods in this pack: " + $mods.Count)
$master.Add(";    0 = Vanilla (no mod)")
for($i=0;$i -lt $Mods.Count;$i++){
  $master.Add(";    " + ($i+1) + " = " + $Mods[$i])
}
$master.Add(";")
$master.Add("; Generated with 3DMigoto Mod Pack Merger by UnLuckyLust")
$master.Add("; ==========================================================")
$master.Add("")
$master.Add("namespace = " + $PackNs + "\Master")
$master.Add("")
$master.Add("[Constants]")
$master.Add("global persist $" + $swapvar + " = 0")
$master.Add("")
$master.Add("[KeyPackCycle]")
$master.Add("key = " + $NextKey)
$master.Add("back = " + $PrevKey)
$master.Add("type = cycle")
$master.Add("$" + $swapvar + " = " + ((0..$Mods.Count) -join ","))
$master.Add("")
$master.Add("; ==========================================================")
$master.Add("; IMPORTANT: Do not DELETE or MODIFY the line below!")
$master.Add("; #MOD_PACK_ROOT v$PackVersion by UnLuckyLust")

$masterPath = Join-Path $root ($PackNs + ".ini")
$deleted = CleanupOldPackRootInis $masterPath
if($deleted.Count -gt 0){
  Write-Host ("INFO: Deleted old pack ini(s): " + ($deleted -join ", "))
}

[System.IO.File]::WriteAllText($masterPath, ($master -join "`n"), $utf8NoBom)

for($i=0;$i -lt $Mods.Count;$i++){
  Patch-ModFolder $Mods[$i] $PackNs ($i+1)
}

Write-Host "OK: Pack ini -> $masterPath"
Write-Host "OK: Patched mod inis (namespaces + gated overrides)"
###PS_END
