@echo off
set "JAVA_HOME=C:\Android\jdk-17"
set "PATH=C:\Android\jdk-17\bin;C:\Android\Sdk\platform-tools;C:\src\flutter\bin;%PATH%"
cd /d "c:\Users\Administrator\Downloads\vibetech_xyz"

echo === Running Flutter App on Android Emulator (emulator-5554) ===
call "C:\src\flutter\bin\flutter.bat" run -d emulator-5554
