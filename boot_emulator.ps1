$env:JAVA_HOME = "C:\Android\jdk-17"
$env:PATH = "C:\Android\jdk-17\bin;C:\Android\Sdk\cmdline-tools\latest\bin;C:\Android\Sdk\platform-tools;C:\Android\Sdk\emulator;$env:PATH"

Write-Host "=== Starting Android Emulator (VibeTech_Emulator) ==="
$emuProcess = Start-Process -FilePath "C:\Android\Sdk\emulator\emulator.exe" -ArgumentList "-avd VibeTech_Emulator -no-snapshot-load -no-boot-anim -netdelay none -netspeed full" -PassThru

Write-Host "Emulator Process ID: $($emuProcess.Id)"
Write-Host "Waiting for ADB device to be detected..."
& "C:\Android\Sdk\platform-tools\adb.exe" wait-for-device

Write-Host "Waiting for sys.boot_completed = 1..."
do {
    Start-Sleep -Seconds 3
    $boot = & "C:\Android\Sdk\platform-tools\adb.exe" shell getprop sys.boot_completed 2>$null
    if ($boot) { $boot = $boot.Trim() }
    Write-Host "Boot check: '$boot'"
} while ($boot -ne "1")

Write-Host "=== Android Emulator is Ready! ==="
& "C:\Android\Sdk\platform-tools\adb.exe" devices
