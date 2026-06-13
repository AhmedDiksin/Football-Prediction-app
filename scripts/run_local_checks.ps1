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

Invoke-Native "flutter" @("pub", "get")
Invoke-Native "dart" @("format", "--set-exit-if-changed", "lib", "test", "integration_test")
Invoke-Native "flutter" @("analyze")
Invoke-Native "flutter" @("test")
