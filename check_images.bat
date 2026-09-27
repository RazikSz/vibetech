@echo off
set "JAVA_HOME=C:\Android\jdk-17"
set "PATH=C:\Android\jdk-17\bin;C:\Android\Sdk\cmdline-tools\latest\bin;C:\Android\Sdk\platform-tools;%PATH%"
C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat --list | findstr /i "system-images;android-34"
