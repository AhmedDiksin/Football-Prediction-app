$ErrorActionPreference = "Stop"

function Add-IfExists($path) {
  if ((Test-Path $path) -and (($env:Path -split ";") -notcontains $path)) {
    $env:Path = "$path;$env:Path"
  }
}

if (Test-Path "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot") {
  $env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"
}
if (Test-Path "C:\tmp\android-sdk") {
  $env:ANDROID_HOME = "C:\tmp\android-sdk"
  $env:ANDROID_SDK_ROOT = "C:\tmp\android-sdk"
}

Add-IfExists "C:\Program Files\Git\cmd"
Add-IfExists "C:\tmp\flutter\bin"
Add-IfExists "C:\tmp\android-sdk\platform-tools"
Add-IfExists "C:\tmp\android-sdk\emulator"
Add-IfExists "C:\tmp\android-sdk\cmdline-tools\latest\bin"
Add-IfExists "$env:JAVA_HOME\bin"

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "$name is not available on PATH. See scripts/setup_android_toolchain.md."
  }
}

function Invoke-Native($command, $arguments) {
  & $command @arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$command $($arguments -join ' ') failed with exit code $LASTEXITCODE."
  }
}

Require-Command flutter
Require-Command adb
Require-Command emulator

$deviceId = $env:FLUTTER_TEST_DEVICE_ID

if (-not $deviceId) {
  $adbDevices = adb devices | Select-String -Pattern "device$"
  $online = $adbDevices | Select-Object -First 1
  if ($online) {
    $deviceId = ($online.ToString() -split "\s+")[0]
  }
}

if (-not $deviceId) {
  $avd = emulator -list-avds | Select-Object -First 1
  if (-not $avd) {
    throw "No Android emulator found. Create one in Android Studio first."
  }
  adb kill-server | Out-Null
  Start-Process `
    -FilePath "emulator" `
    -ArgumentList "-avd", $avd, "-no-window", "-no-audio", "-gpu", "swiftshader_indirect", "-no-snapshot", "-wipe-data", "-no-boot-anim" `
    -WindowStyle Hidden
  adb wait-for-device
  for ($i = 0; $i -lt 120; $i++) {
    Start-Sleep -Seconds 2
    $booted = (adb shell getprop sys.boot_completed 2>$null).Trim()
    if ($booted -eq "1") {
      break
    }
  }
  if ($booted -ne "1") {
    throw "Android emulator did not finish booting."
  }
  $deviceId = ((adb devices | Select-String -Pattern "device$" | Select-Object -First 1).ToString() -split "\s+")[0]
}

Invoke-Native "flutter" @("pub", "get")
Invoke-Native "flutter" @("test", "integration_test", "-d", $deviceId, "--dart-define=APP_MODE=demo")
