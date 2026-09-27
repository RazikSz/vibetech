@echo off
set "JAVA_HOME=C:\Android\jdk-17"
set "PATH=C:\Android\jdk-17\bin;C:\Android\Sdk\cmdline-tools\latest\bin;C:\Android\Sdk\platform-tools;C:\Android\Sdk\emulator;C:\src\flutter\bin;%PATH%"

echo [1/3] Starting Android Emulator VibeTech_Emulator...
start "" "C:\Android\Sdk\emulator\emulator.exe" -avd VibeTech_Emulator -no-snapshot-load -no-boot-anim -netdelay none -netspeed full

echo [2/3] Waiting for ADB to detect emulator...
"C:\Android\Sdk\platform-tools\adb.exe" wait-for-device

echo [3/3] Waiting for Android OS to finish booting...
:wait_boot
for /f "tokens=*" %%a in ('"C:\Android\Sdk\platform-tools\adb.exe" shell getprop sys.boot_completed 2^>nul') do set BOOT_STATUS=%%a
if "%BOOT_STATUS%"=="1" goto booted
timeout /t 2 /nobreak >nul
goto wait_boot

:booted
echo Android Emulator is fully booted and ready!
"C:\Android\Sdk\platform-tools\adb.exe" devices
