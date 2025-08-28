@echo off

set name=game

set GAME_RUNNING=false

set BUILD_DIR=build
set OUT_DIR=%BUILD_DIR%\hot_reload
set GAME_PDBS_DIR=%OUT_DIR%\game_pdbs

set EXE=%name%_hot_reload.exe

:: Check if game is running
FOR /F %%x IN ('tasklist /NH /FI "IMAGENAME eq %EXE%"') DO IF %%x == %EXE% set GAME_RUNNING=true

if not exist %BUILD_DIR% mkdir %BUILD_DIR%
if not exist %OUT_DIR% mkdir %OUT_DIR%


if %GAME_RUNNING% == false (
	for %%f in ("%OUT_DIR%\*") do (
        if /i not "%%~nxf"=="raylib.dll" (
            if /i not "%%~nxf"=="%name%_hot_reload.exe" (
                del "%%f"
            )
        )
    )
	if not exist "%GAME_PDBS_DIR%" mkdir %GAME_PDBS_DIR%
	echo 0 > %GAME_PDBS_DIR%\pdb_number
)

set /a PDB_NUMBER=%PDB_NUMBER%+1
echo %PDB_NUMBER% > %GAME_PDBS_DIR%\pdb_number


echo Building %name%.dll

odin build source -debug -define:RAYLIB_SHARED=true -build-mode:dll -out:%OUT_DIR%/%name%.dll -pdb-name:%GAME_PDBS_DIR%\%name%_%PDB_NUMBER%.pdb > nul

IF %ERRORLEVEL% NEQ 0 exit /b 1

:: If game.exe already running: Then only compile game.dll and exit cleanly
if %GAME_RUNNING% == true (
	echo Hot reloading... && exit /b 0
)

:: Build game.exe, which starts the program and loads game.dll och does the logic for hot reloading.

:: echo Building %EXE%
:: odin build source\main_hot_reload -debug -out:%OUT_DIR%\%EXE% -pdb-name:%OUT_DIR%\main_hot_reload.pdb

IF %ERRORLEVEL% NEQ 0 exit /b 1

set ODIN_PATH=

for /f %%i in ('odin root') do set "ODIN_PATH=%%i"

if not exist ".\%OUT_DIR%\raylib.dll" (
	if exist "%ODIN_PATH%vendor\raylib\windows\raylib.dll" (
		echo raylib.dll not found at .\%OUT_DIR%\raylib.dll . Copying from %ODIN_PATH%\vendor\raylib\windows\raylib.dll
		copy "%ODIN_PATH%\vendor\raylib\windows\raylib.dll" %OUT_DIR%
		IF %ERRORLEVEL% NEQ 0 exit /b 1
	) else (
		echo "Please copy raylib.dll from <your_odin_compiler>/vendor/raylib/windows/raylib.dll to the same directory as game.exe"
		exit /b 1
	)
)

if "%~1"=="run" (
	echo Running %EXE%...
	start %EXE%
)