$ErrorActionPreference = "Stop"

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "$name is not available on PATH. See scripts/setup_android_toolchain.md."
  }
}

Require-Command flutter
Require-Command adb
Require-Command emulator

$deviceId = $env:FLUTTER_TEST_DEVICE_ID

if (-not $deviceId) {
  $devices = flutter devices --machine | ConvertFrom-Json
  $android = $devices | Where-Object { $_.targetPlatform -like "android*" } | Select-Object -First 1
  if ($android) {
    $deviceId = $android.id
  }
}

if (-not $deviceId) {
  $avd = emulator -list-avds | Select-Object -First 1
  if (-not $avd) {
    throw "No Android emulator found. Create one in Android Studio first."
  }
  Start-Process -FilePath "emulator" -ArgumentList "-avd", $avd, "-netdelay", "none", "-netspeed", "full"
  adb wait-for-device
  Start-Sleep -Seconds 20
  $deviceId = "emulator-5554"
}

flutter pub get
flutter test integration_test -d $deviceId --dart-define=APP_MODE=demo
