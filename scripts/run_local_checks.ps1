$ErrorActionPreference = "Stop"

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "$name is not available on PATH. See scripts/setup_android_toolchain.md."
  }
}

Require-Command flutter

flutter pub get
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
