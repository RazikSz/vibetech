@echo off
set "JAVA_HOME=C:\Android\jdk-17"
set "PATH=C:\Android\jdk-17\bin;C:\Android\Sdk\cmdline-tools\latest\bin;C:\Android\Sdk\platform-tools;C:\Android\Sdk\emulator;%PATH%"

echo --- STEP 1: Installing Android Emulator Hypervisor Driver (AEHD) ---
if exist "C:\Android\Sdk\extras\google\Android_Emulator_Hypervisor_Driver\silent_install.bat" (
    call "C:\Android\Sdk\extras\google\Android_Emulator_Hypervisor_Driver\silent_install.bat"
) else (
    echo AEHD directory not found, skipping driver install...
)

echo --- STEP 2: Creating Android Virtual Device (AVD) ---
echo no | call "C:\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd -n VibeTech_Emulator -k "system-images;android-34;google_apis;x86_64" --device "pixel_6" --force

echo --- STEP 3: Verifying AVD list ---
call "C:\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat" list avd
