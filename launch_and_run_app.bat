@echo off
set "JAVA_HOME=C:\Android\jdk-17"
set "PATH=C:\Android\jdk-17\bin;C:\Android\Sdk\cmdline-tools\latest\bin;C:\Android\Sdk\platform-tools;C:\Android\Sdk\emulator;C:\src\flutter\bin;%PATH%"

echo === Checking / Starting Emulator ===
start "" "C:\Android\Sdk\emulator\emulator.exe" -avd VibeTech_Emulator -no-snapshot-load -no-boot-anim -no-audio -netdelay none -netspeed full

echo === Waiting for emulator to be detected by ADB ===
"C:\Android\Sdk\platform-tools\adb.exe" wait-for-device

echo === Waiting for Android OS boot completion (sys.boot_completed) ===
:wait_boot
for /f "tokens=*" %%a in ('"C:\Android\Sdk\platform-tools\adb.exe" shell getprop sys.boot_completed 2^>nul') do set BOOT_STATUS=%%a
if "%BOOT_STATUS%"=="1" goto booted
timeout /t 3 /nobreak >nul
goto wait_boot

:booted
echo Device booted successfully!
"C:\Android\Sdk\platform-tools\adb.exe" devices
echo === Building and launching VibeTech on emulator ===
cd /d "c:\Users\Administrator\Downloads\vibetech_xyz"
call "C:\src\flutter\bin\flutter.bat" run -d emulator-5554
