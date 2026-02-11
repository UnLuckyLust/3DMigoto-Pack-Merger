@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
title 3DMigoto Mod Pack Merger
pushd "%~dp0"
set "ROOT=%CD%"
set "Version=1.2.0"

rem ===================================
rem  USER CONFIG (these can be changed)
rem ===================================
set "CYCLE_NEXT_KEY=VK_ADD"
set "CYCLE_PREV_KEY=VK_SUBTRACT"
set "INCLUDE_VANILLA=1"
rem ==================================

rem ==========
rem  LANGUAGE
rem ==========
set "APP_LANG_DEFAULT=en"
set "APP_LANG=%APP_LANG_DEFAULT%"
set "LANG_DIR=%ROOT%\locales"
set "REG_KEY=HKCU\Software\UnLuckyLust\3DMigotoModPackMerger"
set "REG_VAL=AppLang"

rem =========
rem  VERSION
rem =========
set "VERSION_URL=https://raw.githubusercontent.com/UnLuckyLust/3DMigoto-Pack-Merger/dev/version.txt"
set "UPDATE_URL=https://raw.githubusercontent.com/UnLuckyLust/3DMigoto-Pack-Merger/main/ModPackMerger.bat"

call :LOAD_SAVED_LANG
call :init_ansi
call :BANNER
call :CHECK_VERSION

:ASK_NAME
set "DEFAULT_PACK="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -NoLogo -Command ^
  "$root = '%ROOT%'; " ^
  "$rx1 = '(?im)^\s*;\s*#MOD_PACK_ROOT\b'; " ^
  "$rx2 = '(?im)^\s*\[KeyPackCycle\]\s*$'; " ^
  "$packs = Get-ChildItem -LiteralPath $root -File -Filter '*.ini' -ErrorAction SilentlyContinue | " ^
  "  Where-Object { try { $t=[IO.File]::ReadAllText($_.FullName); ($t -match $rx1) -and ($t -match $rx2) } catch { $false } }; " ^
  "if($packs.Count -eq 1){ [IO.Path]::GetFileNameWithoutExtension($packs[0].Name) }"`) do set "DEFAULT_PACK=%%P"
  
call :TAG INPUT "!T_PROMPT_ENTER_PACK!"
if defined DEFAULT_PACK (
  call :TF1 MSG T_FOUND_EXISTING_PACK "'%DEFAULT_PACK%'"
  call :TAG DIM "!MSG!"
  call :TAG DIM "!T_FOUND_EXISTING_PACK_HINT!"
  echo.
) else (
  call :TAG DIM "!T_EXAMPLE_PACK_NAME!"
  echo.
)

set "VSTATE=ON"
if "%INCLUDE_VANILLA%"=="0" set "VSTATE=OFF"

call :TAG DIM "!T_AVAILABLE_COMMANDS!"
if /I "!NEED_UPDATE!"=="1" (
  call :TF1 MSG T_CMD_U "U"
  call :TAG OK "!MSG!"
)
call :TF1 MSG T_CMD_A "A"
call :TAG DIM "!MSG!"
call :TF1 MSG T_CMD_R "R"
call :TAG DIM "!MSG!"
call :TF1 MSG T_CMD_R1 "R1"
call :TAG DIM "!MSG!"
call :TF2 MSG T_CMD_V "V" "!VSTATE!"
call :TAG DIM "!MSG!"
call :TF2 MSG T_LANG_KEY "L" "!T_LANG_NAME!"
call :TAG DIM "!MSG!"
call :TF1 MSG T_CMD_X "X"
call :TAG DIM "!MSG!"
set "CHAR_NAME="
set /p "CHAR_NAME=> "

for /f "tokens=* delims= " %%A in ("%CHAR_NAME%") do set "CHAR_NAME=%%A"
if "!NEED_UPDATE!"=="1" if /I "%CHAR_NAME%"=="U" goto DOWNLOAD_UPDATE
if /I "%CHAR_NAME%"=="A"  goto ADD
if /I "%CHAR_NAME%"=="R"  goto RESTORE
if /I "%CHAR_NAME%"=="R1" goto RESTORE_ONE
if /I "%CHAR_NAME%"=="V"  goto TOGGLE_VANILLA
if /I "%CHAR_NAME%"=="L"  goto LANG_SELECT
if /I "%CHAR_NAME%"=="X"  exit /b 0

if "%CHAR_NAME%"=="" (
  if defined DEFAULT_PACK ( set "CHAR_NAME=%DEFAULT_PACK%"
  ) else (
    call :RESTART_MSG WARN "!T_ERR_PACK_EMPTY!"
    goto RESTART
  )
)

call :DETECT_MODS || exit /b 1

echo.
call :TF1 MSG T_DETECTED_MODS "%COUNT%"
call :TAG OK "!MSG!"
for /l %%I in (0,1,%END%) do (
  set /a DISP=%%I+1
  call :TAG DIM " !DISP! = !MOD_%%I!"
)

rem ==============================
rem generate pack ini + patch mods
rem ==============================

echo.
call :TF1 MSG T_PRESS_KEY_GENERATE "!CHAR_NAME!.ini"
call :TAG INPUT "!MSG!"
pause >nul
echo.
call :TAG INFO "!T_MERGING!"
call :TAG DIM "!T_MERGING_HINT!"

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
  "& $sb -Root '%ROOT%' -Pack '%CHAR_NAME%' -ModsJoined '%MODS_JOINED%' -IncludeVanilla %INCLUDE_VANILLA% -NextKey '%CYCLE_NEXT_KEY%' -PrevKey '%CYCLE_PREV_KEY%' -NextPretty '%NEXT_PRETTY%' -PrevPretty '%PREV_PRETTY%' -PackVersion '%Version%' -PackTitleTpl '%T_PACK_TITLE%' -PackCycleTpl '%T_PACK_CYCLE%' -PackTotalTpl '%T_PACK_TOTAL%' -PackVanillaLine '%T_PACK_VANILLA%' -PackImportant '%T_PACK_IMPORTANT%'" ^
  1>"%LOG_OUT%" 2>"%LOG_ERR%"
endlocal

set "PSERR=%ERRORLEVEL%"

if not "%PSERR%"=="0" (
  echo.
  call :TAG ERR "!T_ERR_FAIL_CREATE!"
  call :TF1 MSG T_ERR_DETAILS_SAVED "%LOG_ERR%"
  call :TAG DIM "!MSG!"
  call :WAIT_CLOSE
  exit /b 1
)

echo.
call :TAG OK "!T_OK_CREATED!"
call :TAG DIM "!T_PUT_FOLDER!"
call :WAIT_CLOSE
exit /b 0

rem ==============
rem user functions
rem ==============

:TOGGLE_VANILLA
if "%INCLUDE_VANILLA%"=="1" (
  set "INCLUDE_VANILLA=0"
) else (
  set "INCLUDE_VANILLA=1"
)
goto RESTART

:ADD
echo.
call :TAG WARN "!T_WARN_ADD!"

call :DETECT_MODS || exit /b 1

set "PACK_INI="
set "PACK_INI_COUNT=0"

for /f "usebackq delims=" %%F in (`powershell -NoProfile -NoLogo -Command ^
  "$files = Get-ChildItem -LiteralPath '%ROOT%' -Filter *.ini -File | Where-Object { " ^
  "  try { $t = Get-Content -LiteralPath $_.FullName -Raw; " ^
  "        ($t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\b') -and ($t -match '(?im)^\s*\[KeyPackCycle\]\s*$') } catch { $false }" ^
  "}; " ^
  "$files | ForEach-Object { $_.Name }"`) do (
  set /a PACK_INI_COUNT+=1
  if "!PACK_INI_COUNT!"=="1" set "PACK_INI=%%F"
)

if "!PACK_INI_COUNT!"=="0" (
  echo.
  call :TAG ERR "!T_ERR_ADD_FAIL!"
  call :TF1 MSG T_ERR_NO_PACK_INI "(*.ini)"
  call :TAG DIM "!MSG!"
  echo.
  call :TAG INPUT "!T_PRESS_KEY_RESTART!"
  pause >nul
  goto RESTART
)

if not "!PACK_INI_COUNT!"=="1" (
  echo.
  call :TAG ERR "!T_ERR_ADD_FAIL!"
  call :TAG DIM "!T_ERR_MULTI_PACK_INI!"
  powershell -NoProfile -NoLogo -Command ^
    "Get-ChildItem -LiteralPath '%ROOT%' -Filter *.ini -File | Where-Object { " ^
    "  try { $t = Get-Content -LiteralPath $_.FullName -Raw; " ^
    "        ($t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\b') -and ($t -match '(?im)^\s*\[KeyPackCycle\]\s*$') } catch { $false }" ^
    "} | ForEach-Object { '  - ' + $_.Name }"
  call :TAG DIM "!T_ERR_KEEP_ONE!"
  echo.
  call :TAG INPUT "!T_PRESS_KEY_RESTART!"
  pause >nul
  goto RESTART
)

goto ADD_HAVE_PACK

:ADD_HAVE_PACK
call :TAG INPUT "!T_PRESS_KEY_CONTINUE!"
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
  "& $sb -Root '%ROOT%' -Add -PackIni '%PACK_INI%' -ModsJoined '%MODS_JOINED%' -NextKey '%CYCLE_NEXT_KEY%' -PrevKey '%CYCLE_PREV_KEY%' -NextPretty '%NEXT_PRETTY%' -PrevPretty '%PREV_PRETTY%' -PackVersion '%Version%' -PackTitleTpl '%T_PACK_TITLE%' -PackCycleTpl '%T_PACK_CYCLE%' -PackTotalTpl '%T_PACK_TOTAL%' -PackVanillaLine '%T_PACK_VANILLA%' -PackImportant '%T_PACK_IMPORTANT%'" ^
  1>"%LOG_OUT%" 2>"%LOG_ERR%"
endlocal

set "PSERR=%ERRORLEVEL%"

echo.
if not "%PSERR%"=="0" (
  call :TAG ERR "!T_ERR_ADD_FAIL!"
  call :TF1 MSG T_ERR_DETAILS_SAVED "%LOG_ERR%"
  call :TAG DIM "!MSG!"
  echo.
  call :TAG INPUT "!T_PRESS_KEY_RESTART!"
  pause >nul
  goto RESTART
)

call :TAG OK "!T_OK_ADD_COMPLETE!"
call :WAIT_CLOSE
exit /b 0

:RESTORE
echo.
call :TF1 MSG T_WARN_RESTORE "*.ini.disabled"
call :TAG WARN "!MSG!"

call :DETECT_MODS || exit /b 1

call :TAG INPUT "!T_PRESS_KEY_CONTINUE!"
pause >nul

set "LOG_OUT=%TEMP%\3DMigoto_restore_out.txt"
set "LOG_ERR=%TEMP%\3DMigoto_restore_err.txt"
del "%LOG_OUT%" >nul 2>&1
del "%LOG_ERR%" >nul 2>&1

echo.
call :TAG INFO "!T_RESTORING!"

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
  call :TAG ERR "!T_ERR_RESTORE_FAIL!"
  call :TF1 MSG T_ERR_DETAILS_SAVED "%LOG_ERR%"
  call :TAG DIM "!MSG!"
  echo.
  call :TAG INPUT "!T_PRESS_KEY_RESTART!"
  pause >nul
  goto RESTART
)

call :TAG OK "!T_OK_RESTORE_COMPLETE!"
call :WAIT_CLOSE
exit /b 0

:RESTORE_ONE
echo.
call :TAG WARN "!T_WARN_RESTORE1!"
call :TAG DIM  "!T_WARN_RESTORE1_NOTE!"

call :DETECT_MODS || exit /b 1
echo.
call :TF1 MSG T_DETECTED_MODS "%COUNT%"
call :TAG OK "!MSG!"
for /l %%I in (0,1,%END%) do (
  set /a DISP=%%I+1
  call :TAG DIM " !DISP! = !MOD_%%I!"
)

echo.
set "PICK="
set "NONNUM="

if %COUNT% EQU 1 (
  call :TF1 MSG T_WARN_ONLY_ONE "!MOD_0!"
  call :TAG WARN "!MSG!"
  call :TAG INPUT "!T_PROMPT_REMOVE_ONE!"
  choice /c YN /n >nul
  if errorlevel 2 (
    echo.
    call :TAG WARN "!T_CANCELED!"
    echo.
    call :TAG INPUT "!T_PRESS_KEY_RESTART!"
    pause >nul
    goto RESTART
  )
  set "PICK=1"
) else (
  call :TF1 MSG T_PROMPT_PICK_REMOVE "%COUNT%"
  call :TAG INPUT "!MSG!"
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
    call :TF1 MSG T_ERR_INVALID_NUM "%COUNT%"
    call :TAG ERR "!MSG!"
    echo.
    call :TAG INPUT "!T_PRESS_KEY_RESTART!"
    pause >nul
    goto RESTART
  )
)

set /a IDX=PICK-1
call set "TARGET=%%MOD_!IDX!%%"

echo.
call :TF1 MSG T_WARN_RESTORING_MOD "'!TARGET!'"
call :TAG WARN "!MSG!"
call :TAG INPUT "!T_PRESS_KEY_CONTINUE!"
pause >nul

set "LOG_OUT=%TEMP%\3DMigoto_restore1_out.txt"
set "LOG_ERR=%TEMP%\3DMigoto_restore1_err.txt"
del "%LOG_OUT%" >nul 2>&1
del "%LOG_ERR%" >nul 2>&1

echo.
call :TF1 MSG T_INFO_RESTORING_MOD "'%TARGET%'"
call :TAG INFO "!MSG!"

setlocal DisableDelayedExpansion
powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -Command ^
  "$bat = Get-Content -LiteralPath '%~f0' -Raw; " ^
  "$m = [regex]::Match($bat,'###PS_BEGIN\r?\n(.*?)\r?\n###PS_END','Singleline'); " ^
  "if(-not $m.Success){ throw 'Embedded PS script not found.' } " ^
  "$sb = [scriptblock]::Create($m.Groups[1].Value); " ^
  "& $sb -Root '%ROOT%' -RestoreOne -ModFolder '%TARGET%' -PackVersion '%Version%' -PackTitleTpl '%T_PACK_TITLE%' -PackCycleTpl '%T_PACK_CYCLE%' -PackTotalTpl '%T_PACK_TOTAL%' -PackVanillaLine '%T_PACK_VANILLA%' -PackImportant '%T_PACK_IMPORTANT%'" ^
  1>"%LOG_OUT%" 2>"%LOG_ERR%"
endlocal

set "PSERR=%ERRORLEVEL%"

echo.
if not "%PSERR%"=="0" (
  call :TF1 MSG T_ERR_RESTORE1_FAIL "'!TARGET!'"
  call :TAG ERR "!MSG!"
  call :TF1 MSG T_ERR_DETAILS_SAVED "%LOG_ERR%"
  call :TAG DIM "!MSG!"
  echo.
  call :TAG INPUT "!T_PRESS_KEY_RESTART!"
  pause >nul
  goto RESTART
)

call :TF1 MSG T_OK_RESTORED_MOD "'!TARGET!'"
call :TAG OK "!MSG!"
call :TF1 MSG T_WARN_MOVE_OUT "'!TARGET!'"
call :TAG WARN "!MSG!"
call :TAG DIM "!T_WARN_CONFLICT!"
call :WAIT_CLOSE
exit /b 0

rem =======
rem helpers
rem =======

:CHECK_VERSION
setlocal EnableDelayedExpansion
set "REMOTE_VER="
set "NEED_UPDATE=0"

for /f "usebackq delims=" %%V in (`
  powershell -NoProfile -NoLogo -Command ^
    "try { ((Invoke-WebRequest -UseBasicParsing '%VERSION_URL%').Content -split '\r?\n')[0].Trim() } catch { '' }"
`) do set "REMOTE_VER=%%V"
if not defined REMOTE_VER (
  set "NEED_UPDATE=0"
  goto _ver_done
)

set "LOCAL_OK="
set "REMOTE_OK="
echo(%Version%| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul && set "LOCAL_OK=1"
echo(!REMOTE_VER!| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul && set "REMOTE_OK=1"
if not defined LOCAL_OK (
  set "NEED_UPDATE=1"
  call :TF1 MSG T_VERCHK_UNK_LOCAL "%Version%"
  call :TAG WARN "!MSG!"
  call :TF1 MSG T_VERCHK_UPDATE_HINT "U"
  call :TAG DIM "!MSG!"
  echo.
  goto _ver_done
)
if not defined REMOTE_OK (
  set "NEED_UPDATE=1"
  call :TAG ERR "!T_VERCHK_UNK_REMOTE!"
  echo.
  goto _ver_done
)

set "VER_STATE="
for /f "usebackq delims=" %%R in (`
  powershell -NoProfile -NoLogo -Command ^
    "$L='%Version%'; $R='%REMOTE_VER%'; if([version]$L -lt [version]$R){'NEW'} elseif([version]$L -gt [version]$R){'OLD'} else{'SAME'}"
`) do set "VER_STATE=%%R"

if /I "!VER_STATE!"=="NEW" (
  set "NEED_UPDATE=1"
  call :TF2 MSG T_VERCHK_NEW "!REMOTE_VER!" "%Version%"
  call :TAG WARN "!MSG!"
  call :TF1 MSG T_VERCHK_UPDATE_HINT "U"
  call :TAG DIM "!MSG!"
  echo.
)
if /I "!VER_STATE!"=="OLD" (
  set "NEED_UPDATE=1"
  call :TF1 MSG T_VERCHK_UNK_VERSION "%Version%"
  call :TAG ERR "!MSG!"
  call :TF1 MSG T_VERCHK_UPDATE_HINT "U"
  call :TAG DIM "!MSG!"
  echo.
)

:_ver_done
endlocal & set "NEED_UPDATE=%NEED_UPDATE%"
exit /b 0

:DOWNLOAD_UPDATE
setlocal EnableDelayedExpansion
set "TMP_NEW=%TEMP%\ModPackMerger.new.bat"
set "TMP_VER=%TEMP%\ModPackMerger.version.txt"
del "%TMP_NEW%" >nul 2>&1
del "%TMP_VER%" >nul 2>&1
set "SELF=%~f0"
set "UPD_HELPER=%TEMP%\ModPackMerger_apply_update_%RANDOM%.bat"

echo.
call :TAG INFO "!T_UPDATING!"
call :TAG DIM  "!T_UPDATING_HINT!"
echo.

powershell -NoProfile -NoLogo -NonInteractive -Command ^
  "try { Invoke-WebRequest -UseBasicParsing '%UPDATE_URL%' -OutFile '%TMP_NEW%'; exit 0 } catch { exit 1 }"
if errorlevel 1 goto _fail

powershell -NoProfile -NoLogo -NonInteractive -Command ^
  "try { Invoke-WebRequest -UseBasicParsing '%VERSION_URL%' -OutFile '%TMP_VER%'; exit 0 } catch { exit 1 }"
if errorlevel 1 goto _bad

set "EXPECTED_SHA="
for /f "usebackq delims=" %%H in (`powershell -NoProfile -NoLogo -Command "(Get-Content -LiteralPath '%TMP_VER%' | Select-Object -Skip 1 -First 1).Trim()"`) do set "EXPECTED_SHA=%%H"

if not defined EXPECTED_SHA goto _bad

echo(%EXPECTED_SHA%| findstr /r /i "^[0-9A-F][0-9A-F]*$" >nul || goto _bad
if "%EXPECTED_SHA:~63,1%"=="" goto _bad
if not "%EXPECTED_SHA:~64,1%"=="" goto _bad

for %%A in ("%TMP_NEW%") do if %%~zA LSS 1000 goto _bad

set "DOWN_SHA="
for /f "tokens=1" %%S in ('certutil -hashfile "%TMP_NEW%" SHA256 ^| findstr /r /i "^[0-9A-F][0-9A-F]*$"') do (
  set "DOWN_SHA=%%S"
  goto :_gotsha
)

:_gotsha
if not defined DOWN_SHA goto _bad
if /I not "%DOWN_SHA%"=="%EXPECTED_SHA%" goto _bad
goto _ok

:_fail
call :TAG ERR "!T_UPDATE_FAILED!"
call :TAG DIM "!T_UPDATE_FAILED_HINT!"
del "%TMP_NEW%" >nul 2>&1
del "%TMP_VER%" >nul 2>&1
endlocal
call :WAIT_CLOSE
exit /b 0

:_bad
call :TAG ERR "!T_UPDATE_BAD_FILE!"
del "%TMP_NEW%" >nul 2>&1
del "%TMP_VER%" >nul 2>&1
endlocal
call :WAIT_CLOSE
exit /b 0

:_ok
call :TAG OK "!T_UPDATE_SUCCESS!"
echo.
call :TAG INPUT "!T_PRESS_KEY_RESTART!"
pause >nul

> "%UPD_HELPER%" echo @echo off
>>"%UPD_HELPER%" echo title 3DMigoto MPM Updater
>>"%UPD_HELPER%" echo setlocal
>>"%UPD_HELPER%" echo ping 127.0.0.1 -n 2 ^>nul
>>"%UPD_HELPER%" echo copy /y "%TMP_NEW%" "%SELF%" ^>nul
>>"%UPD_HELPER%" echo del "%TMP_NEW%" ^>nul 2^>^&1
>>"%UPD_HELPER%" echo del "%TMP_VER%" ^>nul 2^>^&1
>>"%UPD_HELPER%" echo start "" "%ComSpec%" /c ""%SELF%""
>>"%UPD_HELPER%" echo del "%%~f0" ^>nul 2^>^&1

endlocal & start "" "%ComSpec%" /c ""%UPD_HELPER%"" & exit /b 0

:DETECT_MODS
for /f "delims=" %%V in ('set MOD_ 2^>nul') do set "%%V="

set /a COUNT=0
for /d %%D in (*) do (
  call :HAS_ANY_INI "%%~fD"
  if not errorlevel 1 (
    set "MOD_!COUNT!=%%~nxD"
    set /a COUNT+=1
  )
)

if %COUNT% LSS 1 (
  set "END=0"
  set "MODS_JOINED="

  echo.
  call :TAG ERR "!T_ERR_NO_MODS_FOUND!"
  call :TAG DIM "!T_ERR_NO_MODS_HINT1!"
  call :TAG DIM "!T_ERR_NO_MODS_HINT2!"
  call :TAG DIM "!T_ERR_NO_MODS_HINT3!"
  call :TAG DIM "!T_ERR_NO_MODS_HINT4!"
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

:HAS_ANY_INI
setlocal
for /f "delims=" %%F in ('
  dir /b /a-d /s "%~1\*.ini" 2^>nul ^
  ^| findstr /i /v "\.ini\.disabled$" ^
  ^| findstr /i /v "\\DISABLED.*\.ini$"
') do (
  endlocal & exit /b 0
)
endlocal & exit /b 1

:RESTART_MSG
set "RESTART_TYPE=%~1"
set "RESTART_TEXT=%~2"
exit /b 0

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
call :TAG INPUT "!T_PRESS_KEY_CLOSE!"
pause >nul
exit /b 0

:BANNER
call :vk_pretty "%CYCLE_NEXT_KEY%" NEXT_PRETTY
call :vk_pretty "%CYCLE_PREV_KEY%" PREV_PRETTY
call :LOAD_LANG
call :TAG DIM "===================================================="
call :TAG DIM "       3DMigoto Mod Pack Merger by UnLuckyLust"
call :TAG DIM "                 version %Version%"
echo.
call :TF2 MSG T_BANNER_KEYS "!NEXT_PRETTY!" "!PREV_PRETTY!"
call :TAG DIM "!MSG!"
call :TAG DIM "       !T_BANNER_KEYS2!"
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

:LOAD_SAVED_LANG
setlocal EnableDelayedExpansion
set "SAVED="
for /f "tokens=2,*" %%A in ('reg query "%REG_KEY%" /v "%REG_VAL%" 2^>nul ^| findstr /i "%REG_VAL%"') do set "SAVED=%%B"
if defined SAVED (
  endlocal & set "APP_LANG=%SAVED%" & exit /b 0
)
endlocal & exit /b 0

:TF1
setlocal EnableDelayedExpansion
set "S=!%~2!"
set "S=!S:{0}=%~3!"
endlocal & set "%~1=%S%"
exit /b 0

:TF2
setlocal EnableDelayedExpansion
set "S=!%~2!"
set "S=!S:{0}=%~3!"
set "S=!S:{1}=%~4!"
endlocal & set "%~1=%S%"
exit /b 0

:LANG_SELECT
call :LANG_MENU
goto RESTART

:SAVE_LANG
reg add "%REG_KEY%" /v "%REG_VAL%" /t REG_SZ /d "%APP_LANG%" /f >nul 2>&1
exit /b 0

:LANG_MENU
setlocal EnableDelayedExpansion

if not exist "%LANG_DIR%\" (
  echo.
  call :TAG WARN "!T_ERR_NO_LANG_DIR!"
  call :TAG INPUT "!T_PRESS_KEY_RESTART!"
  pause >nul
  endlocal & exit /b 0
)

dir /b /a-d "%LANG_DIR%\*.lang" >nul 2>&1
if errorlevel 1 (
  echo.
  call :TAG WARN "!T_ERR_NO_LANG_FILES!"
  call :TAG INPUT "!T_PRESS_KEY_RESTART!"
  pause >nul
  endlocal & exit /b 0
)

for /f "delims=" %%V in ('set LCODE_ 2^>nul') do set "%%V="
for /f "delims=" %%V in ('set LNAME_ 2^>nul') do set "%%V="
for /f "delims=" %%V in ('set SEEN_  2^>nul') do set "%%V="

set /a LC=0

set "LCODE_0=en"
set "LNAME_0=English"
set "SEEN_en=1"
set /a LC=1

for /f "delims=" %%F in ('dir /b /a-d "%LANG_DIR%\*.lang" 2^>nul') do (
  set "CODE=%%~nF"
  for /f "tokens=* delims= " %%A in ("!CODE!") do set "CODE=%%A"

  echo(!CODE!| findstr /r "^[A-Za-z0-9][A-Za-z0-9_-]*$" >nul && (
    if /I not "!CODE!"=="en" if not defined SEEN_!CODE! (
      set "NAME="

      for /f "usebackq tokens=1* delims==" %%K in (`
        findstr /i /r "^ *LANG_NAME *=" "%LANG_DIR%\%%F" 2^>nul
      `) do (
        if not defined NAME set "NAME=%%L"
      )

      for /f "tokens=* delims= " %%B in ("!NAME!") do set "NAME=%%B"
      if "!NAME!"=="" set "NAME=!CODE!"

      set "LCODE_!LC!=!CODE!"
      set "LNAME_!LC!=!NAME!"
      set "SEEN_!CODE!=1"
      set /a LC+=1
    )
  )
)

if !LC! LEQ 1 (
  echo.
  call :TAG WARN "!T_ERR_NO_LANG_FILES!"
  call :TAG INPUT "!T_PRESS_KEY_RESTART!"
  pause >nul
  endlocal & exit /b 0
)

echo.
call :TAG DIM "!T_LANG_MENU_TITLE!"
set /a LAST=LC-1
for /l %%I in (0,1,!LAST!) do (
  if defined LCODE_%%I (
    set /a N=%%I+1
    call :TAG DIM "  !N! = !LNAME_%%I! (!LCODE_%%I!)"
  )
)
echo.

call :TF1 HINTTXT T_LANG_MENU_HINT "!LC!"
call :TAG INPUT "!HINTTXT!"
set "PICK="
set /p "PICK=> "
for /f "tokens=* delims= " %%A in ("!PICK!") do set "PICK=%%A"
if "!PICK!"=="" ( endlocal & exit /b 0 )

set "NONNUM="
for /f "delims=0123456789" %%A in ("!PICK!") do set "NONNUM=%%A"
if defined NONNUM goto _badPick

set /a IDX=!PICK!-1 2>nul
if !IDX! LSS 0 goto _badPick
if !IDX! GEQ !LC! goto _badPick

for %%I in (!IDX!) do (
  set "NEWLANG=!LCODE_%%I!"
  set "NEWLANGNAME=!LNAME_%%I!"
)

endlocal & (
  set "APP_LANG=%NEWLANG%"
  call :SAVE_LANG
  call :TF1 OKTXT T_LANG_CHANGED "%NEWLANGNAME%"
  set "RESTART_TYPE=OK"
  set "RESTART_TEXT=!OKTXT!"
  exit /b 0
)

:_badPick
echo.
call :TF1 ERRTXT T_ERR_INVALID_LANG "!LC!"
call :TAG WARN "!ERRTXT!"
call :TAG INPUT "!T_PRESS_KEY_RESTART!"
pause >nul
endlocal & exit /b 0

:LOAD_LANG_PRECHECK
setlocal EnableDelayedExpansion
if /I "%APP_LANG%"=="en" (
  endlocal & exit /b 0
)
if not exist "%LANG_DIR%\" (
  endlocal & set "APP_LANG=%APP_LANG_DEFAULT%" & exit /b 0
)
if exist "%LANG_DIR%\%APP_LANG%.lang" (
  endlocal & exit /b 0
)
call :AUTO_DETECT_LANG >nul 2>&1
endlocal & exit /b 0

:AUTO_DETECT_LANG
setlocal EnableDelayedExpansion
if not exist "%LANG_DIR%\" (
  endlocal & set "APP_LANG=%APP_LANG_DEFAULT%" & exit /b 0
)

set "HAS_ANY="
for /f "delims=" %%F in ('dir /b /a-d "%LANG_DIR%\*.lang" 2^>nul') do (set "HAS_ANY=1" & goto :_hasLang)
:_hasLang
if not defined HAS_ANY (
  endlocal & set "APP_LANG=%APP_LANG_DEFAULT%" & exit /b 0
)

set "WLC="
for /f "usebackq delims=" %%L in (`powershell -NoProfile -NoLogo -Command "(Get-UICulture).Name"`) do set "WLC=%%L"
set "CAND=en"
if /I "!WLC:~0,2!"=="ru" set "CAND=ru"
if /I "!WLC:~0,2!"=="zh" set "CAND=cn"
if /I "!WLC:~0,2!"=="es" set "CAND=es"
if /I "!WLC:~0,2!"=="pt" set "CAND=pt-br"
if /I "!WLC:~0,2!"=="ko" set "CAND=ko"
if /I "!WLC:~0,2!"=="ja" set "CAND=ja"

if exist "%LANG_DIR%\!CAND!.lang" ( endlocal & set "APP_LANG=!CAND!" & exit /b 0 )
if exist "%LANG_DIR%\en.lang"      ( endlocal & set "APP_LANG=en" & exit /b 0 )

for /f "delims=" %%F in ('dir /b /a-d "%LANG_DIR%\*.lang" 2^>nul') do (
  endlocal & set "APP_LANG=%%~nF" & exit /b 0
)
endlocal & set "APP_LANG=%APP_LANG_DEFAULT%" & exit /b 0

:LOAD_LANG
call :LOAD_LANG_PRECHECK
rem ==================
rem  fallback strings
rem ==================
set "T_LANG_NAME=English"
set "T_BANNER_KEYS=Use {0} or {1} to cycle mods while in-game"
set "T_BANNER_KEYS2=(cycle keys can be changed in config)"
set "T_PROMPT_ENTER_PACK=Enter pack name"
set "T_FOUND_EXISTING_PACK=Found existing pack: {0}"
set "T_FOUND_EXISTING_PACK_HINT=Press Enter to regenerate this pack, or type a new name to create a new pack"
set "T_EXAMPLE_PACK_NAME=Example pack name: RoverPack"
set "T_AVAILABLE_COMMANDS=available commands:"
set "T_CMD_U=  {0}  = update to latest version"
set "T_CMD_A=  {0}  = add mods to the current pack"
set "T_CMD_R=  {0}  = restore all mods"
set "T_CMD_R1=  {0} = restore a single mod"
set "T_CMD_V=  {0}  = add/remove Vanilla (no mods) as cycle option (currently: {1})"
set "T_CMD_X=  {0}  = exit"
set "T_ERR_PACK_EMPTY=Pack Name cannot be empty!"
set "T_DETECTED_MODS=Detected {0} mod folders:"
set "T_PRESS_KEY_GENERATE=Press any key to generate {0} and patch mods..."
set "T_MERGING=Merging mods into one pack..."
set "T_MERGING_HINT=This may take a bit on large mods"
set "T_ERR_FAIL_CREATE=Failed to create mod pack"
set "T_ERR_DETAILS_SAVED=Error details saved to: {0}"
set "T_OK_CREATED=Mod pack created successfully"
set "T_PUT_FOLDER=Put this whole folder in the game Mods folder (keep all subfolders)"
set "T_WARN_ADD=ADD MODS: will add missing mod folders into the current pack"
set "T_ERR_ADD_FAIL=Failed to add mods to pack"
set "T_ERR_NO_PACK_INI=No generated pack ini {0} was found in this folder"
set "T_ERR_MULTI_PACK_INI=More than one generated pack ini was found in this folder:"
set "T_ERR_KEEP_ONE=Keep ONLY one pack ini in this folder, then try again."
set "T_OK_ADD_COMPLETE=Add complete"
set "T_WARN_RESTORE=RESTORE ALL MODS: will restore {0} and delete generated pack ini(s)"
set "T_RESTORING=Restoring all mods..."
set "T_ERR_RESTORE_FAIL=Failed to restore mods"
set "T_OK_RESTORE_COMPLETE=Full restore completed"
set "T_WARN_RESTORE1=RESTORE ONE MOD: restore backups only in ONE mod folder + update pack ini"
set "T_WARN_RESTORE1_NOTE=NOTE: after restoring, move the mod folder OUT of this pack folder!"
set "T_WARN_ONLY_ONE=Only one mod detected: {0}"
set "T_PROMPT_REMOVE_ONE=Remove it? (Y/N)"
set "T_CANCELED=Canceled"
set "T_PROMPT_PICK_REMOVE=Enter number to remove (1-{0})"
set "T_ERR_INVALID_NUM=Invalid number (use 1-{0})"
set "T_WARN_RESTORING_MOD=Restoring mod: {0}"
set "T_INFO_RESTORING_MOD=Restoring mod: {0}"
set "T_ERR_RESTORE1_FAIL=Failed to restore mod: {0}"
set "T_ERR_RESTORE1_HINT=Make sure there is .ini.disabled file in the mod folder / mod exists in the pack"
set "T_OK_RESTORED_MOD=Restored mod: {0}"
set "T_WARN_MOVE_OUT=IMPORTANT: You can now move the {0} folder OUT of this pack folder"
set "T_WARN_CONFLICT=If you leave it here, it will conflict with the pack ini!"
set "T_PRESS_KEY_RESTART=Press any key to restart..."
set "T_PRESS_KEY_CONTINUE=Press any key to continue..."
set "T_PRESS_KEY_CLOSE=Press any key to close..."
set "T_PACK_TITLE={0} Mod Pack"
set "T_PACK_CYCLE=Use {0} or {1} to cycle mods"
set "T_PACK_TOTAL=Total mods in this pack: {0}"
set "T_PACK_VANILLA=0 = Vanilla (no mod)"
set "T_ERR_NO_MODS_FOUND=No mod folders found"
set "T_ERR_NO_MODS_HINT1=Put this BAT in a folder that contains 1+ mod folders"
set "T_ERR_NO_MODS_HINT2=Each mod folder must contain (anywhere inside it):"
set "T_ERR_NO_MODS_HINT3=  - one .ini file (in root OR in subfolders like Body/Ornament)"
set "T_ERR_NO_MODS_HINT4=  - a Meshes and/or Textures folder"
set "T_PACK_IMPORTANT=IMPORTANT: Do not DELETE or MODIFY the lines below!"

set "T_VERCHK_UNK_LOCAL=Unrecognized local version"
set "T_VERCHK_UNK_REMOTE=Version check failed, unrecognized remote version"
set "T_VERCHK_NEW=New version available: {0} (you have {1})"
set "T_VERCHK_UNK_VERSION=Unrecognized version detected: {0}"
set "T_VERCHK_UPDATE_HINT=Download the latest version from GameBanana/GitHub, Or press {0} to update"
set "T_UPDATING=Updating..."
set "T_UPDATING_HINT=Downloading the latest version"
set "T_UPDATE_FAILED=Update failed"
set "T_UPDATE_FAILED_HINT=Please download the latest version manually from GameBanana/GitHub"
set "T_UPDATE_BAD_FILE=Downloaded file looks invalid, Try again or update manually"
set "T_UPDATE_SUCCESS=Successfully updated to the latest version"

set "T_LANG_KEY=  {0}  = change language (current: {1})"
set "T_ERR_NO_LANG_DIR=Language folder not found"
set "T_ERR_NO_LANG_FILES=No language files found in locales folder"
set "T_LANG_MENU_TITLE=Select language:"
set "T_LANG_MENU_HINT=Select Language id (1-{0}) (keep empty to cancel)"
set "T_ERR_INVALID_LANG=Invalid selection (use 1-{0})"
set "T_LANG_CHANGED=Language changed to: {0}"

set "LF=%LANG_DIR%\%APP_LANG%.lang"
if not exist "%LF%" exit /b 0

for /f "usebackq tokens=1* delims==" %%A in ("%LF%") do (
  set "K=%%A"
  set "V=%%B"
  if defined K (
    if not "!K:~0,1!"==";" if not "!K:~0,1!"=="#" (
      for /f "tokens=* delims= " %%k in ("!K!") do set "K=%%k"
      set "T_!K!=!V!"
    )
  )
)
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

  [int]$IncludeVanilla = 1,

  [switch]$Restore,
  [switch]$Add,

  [switch]$RestoreOne,
  [string]$ModFolder,

  [string]$NextKey,
  [string]$PrevKey,
  [string]$NextPretty,
  [string]$PrevPretty,

  [string]$PackTitleTpl,
  [string]$PackCycleTpl,
  [string]$PackTotalTpl,
  [string]$PackVanillaLine,
  [string]$PackImportant
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Root).Path
if(Test-Path -LiteralPath $root -PathType Leaf){
  $root = Split-Path -LiteralPath $root -Parent
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$swapvar = "swapvar"
$packActiveVar = "pack_active"

function Sanitize([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return "Pack" }
  ($s -replace '\s+','' -replace '[^A-Za-z0-9_\-]','')
}

if([string]::IsNullOrWhiteSpace($PackVersion)){ $PackVersion = "0.0.0" }
if([string]::IsNullOrWhiteSpace($NextKey)){ $NextKey = 'VK_RIGHT' }
if([string]::IsNullOrWhiteSpace($PrevKey)){ $PrevKey = 'VK_LEFT' }
if([string]::IsNullOrWhiteSpace($NextPretty)){ $NextPretty = $NextKey }
if([string]::IsNullOrWhiteSpace($PrevPretty)){ $PrevPretty = $PrevKey }

if([string]::IsNullOrWhiteSpace($PackTitleTpl)){    $PackTitleTpl = "{0} Mod Pack" }
if([string]::IsNullOrWhiteSpace($PackCycleTpl)){    $PackCycleTpl = "Use {0} or {1} to cycle mods" }
if([string]::IsNullOrWhiteSpace($PackTotalTpl)){    $PackTotalTpl = "Total mods in this pack: {0}" }
if([string]::IsNullOrWhiteSpace($PackVanillaLine)){ $PackVanillaLine = "0 = Vanilla (no mod)" }
if([string]::IsNullOrWhiteSpace($PackImportant)){  $PackImportant = "IMPORTANT: Do not DELETE or MODIFY the lines below!" }

if($RestoreOne -and [string]::IsNullOrWhiteSpace($ModFolder)){
  throw "ModFolder is required for RestoreOne."
}

# --------
# helpers
# --------

function F1([string]$tpl, [string]$a){
  if([string]::IsNullOrWhiteSpace($tpl)){ return "" }
  return ($tpl -replace '\{0\}', $a)
}
function F2([string]$tpl, [string]$a, [string]$b){
  if([string]::IsNullOrWhiteSpace($tpl)){ return "" }
  $s = $tpl -replace '\{0\}', $a
  $s = $s -replace '\{1\}', $b
  return $s
}

function IsGeneratedPackIni([string]$path){
  try{
    $t = [System.IO.File]::ReadAllText($path)
    return ($t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\b') -and
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

  $includeVanilla = $false
  foreach($l in $lines){
    if($l -match '^\s*;\s*#MOD_PACK_ROOT\b'){
      if($l -match '(?i)#VanillaIncluded\b'){ $includeVanilla = $true }
      break
    }
  }

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
    IncludeVanilla  = $includeVanilla
  }
}

function IsPackRootIni([string]$path){
  try{
    $t = [System.IO.File]::ReadAllText($path)
    return ($t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\b')
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

function WritePackIni([string]$packPath, [string]$packNs, [object[]]$mods, [string]$nk, [string]$pk, [bool]$includeVanilla){
  if([string]::IsNullOrWhiteSpace($nk)){ $nk = $NextKey }
  if([string]::IsNullOrWhiteSpace($pk)){ $pk = $PrevKey }

  $cycle = @()
  if($includeVanilla){ $cycle += "0" }
  $cycle += ($mods | Sort-Object Index | ForEach-Object { [string]$_.Index })

  $L = New-Object System.Collections.Generic.List[string]
  $packName = [System.IO.Path]::GetFileNameWithoutExtension($packPath)
  $L.Add("; " + (F1 $PackTitleTpl $packName))
  $L.Add("; " + (F2 $PackCycleTpl $NextPretty $PrevPretty))
  $L.Add(";")
  $L.Add("; " + (F1 $PackTotalTpl ([string]$mods.Count)))
  if($includeVanilla){
    $L.Add(";    " + $PackVanillaLine)
  }
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
  $defaultSwap = 1
  if($includeVanilla){ $defaultSwap = 0 }
  $L.Add("global persist $" + $swapvar + " = " + $defaultSwap)
  $L.Add("global $" + $packActiveVar + " = 0")
  $L.Add("")
  $L.Add("[Present]")
  $L.Add("post $" + $packActiveVar + " = 0")
  $L.Add("")
  $L.Add("[KeyPackCycle]")
  $L.Add("condition = $" + $packActiveVar + " == 1")
  $L.Add("key = " + $nk)
  $L.Add("back = " + $pk)
  $L.Add("type = cycle")
  $L.Add("$" + $swapvar + " = " + ($cycle -join ","))
  $L.Add("")
  $L.Add("; ==========================================================")
  $L.Add("; " + $PackImportant)
  $vanillaTag = ""
  if($includeVanilla){ $vanillaTag = "#VanillaIncluded" }
  $L.Add("; #MOD_PACK_ROOT $vanillaTag")
  $L.Add("; Mod Pack Merger v$PackVersion by UnLuckyLust")

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

  $ifLine = "if `$\" + $packNs + "\Master\" + $swapvar + " == $idx"
  $activeLine = "$\" + $packNs + "\Master\" + $packActiveVar + " = 1"

  foreach($line in $lines){
    $m = $rxSection.Match($line)
    if($m.Success){
      if($didIf){
        $out.Add('endif')
        $out.Add('')
        $didIf = $false
      }

      $sectionName = $m.Groups["name"].Value
      $setActiveInThisSection =
      $sectionName -match '^(?i)TextureOverride.*Component' -or
      $sectionName -match '^(?i)ShaderOverride.*Component'
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

      if($setActiveInThisSection){
        $out.Add($activeLine)
      }

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
  WritePackIni $packFile.FullName $info.Namespace $info.Mods $info.NextKey $info.PrevKey $info.IncludeVanilla
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
    if($t -and $t -match '(?im)^\s*;\s*#MOD_PACK_ROOT\b'){
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

  WritePackIni $packFile.FullName $packNs $info.Mods $info.NextKey $info.PrevKey $info.IncludeVanilla
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
$master.Add("; " + (F1 $PackTitleTpl $PackNs))
$master.Add("; " + (F2 $PackCycleTpl $NextPretty $PrevPretty))
$master.Add(";")
$master.Add("; " + (F1 $PackTotalTpl ([string]$Mods.Count)))
if($IncludeVanilla -eq 1){
  $master.Add(";    " + $PackVanillaLine)
}
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
$defaultSwap = 1
if($IncludeVanilla -eq 1){ $defaultSwap = 0 }
$master.Add("global persist $" + $swapvar + " = " + $defaultSwap)
$master.Add("global $" + $packActiveVar + " = 0")
$master.Add("")
$master.Add("[Present]")
$master.Add("post $" + $packActiveVar + " = 0")
$master.Add("")
$master.Add("[KeyPackCycle]")
$master.Add("condition = $" + $packActiveVar + " == 1")
$master.Add("key = " + $NextKey)
$master.Add("back = " + $PrevKey)
$master.Add("type = cycle")
if($IncludeVanilla -eq 1){
  $master.Add("$" + $swapvar + " = " + ((0..$Mods.Count) -join ","))
} else {
  $master.Add("$" + $swapvar + " = " + ((1..$Mods.Count) -join ","))
}
$master.Add("")
$master.Add("; ==========================================================")
$master.Add("; " + $PackImportant)
$vanillaTag = ""
if($IncludeVanilla -eq 1){ $vanillaTag = "#VanillaIncluded" }
$master.Add("; #MOD_PACK_ROOT $vanillaTag")
$master.Add("; Mod Pack Merger v$PackVersion by UnLuckyLust")

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
