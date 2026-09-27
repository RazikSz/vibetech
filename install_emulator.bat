@echo off
set "JAVA_HOME=C:\Android\jdk-17"
set "PATH=C:\Android\jdk-17\bin;C:\Android\Sdk\cmdline-tools\latest\bin;C:\Android\Sdk\platform-tools;%PATH%"

echo --- STEP 1: Accepting Android SDK Licenses ---
(for /L %%i in (1,1,25) do echo y) | call "C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --licenses

echo --- STEP 2: Installing emulator, hypervisor driver, and system-image ---
(for /L %%i in (1,1,10) do echo y) | call "C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "emulator" "extras;google;Android_Emulator_Hypervisor_Driver" "system-images;android-34;google_apis;x86_64"

echo --- Installation complete! ---
