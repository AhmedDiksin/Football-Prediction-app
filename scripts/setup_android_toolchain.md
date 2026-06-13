# Windows Android Toolchain Setup

This project can be rebuilt quickly, but the current workspace may not have Flutter, Git, or Android SDK tools installed.

## Install Required Tools

Install Git, Flutter, Android Studio, and GitHub CLI:

```powershell
winget install Git.Git --accept-source-agreements --accept-package-agreements
winget install GitHub.cli --accept-source-agreements --accept-package-agreements
winget install Google.AndroidStudio --accept-source-agreements --accept-package-agreements
```

Install Flutter manually from the official SDK archive:

1. Open https://docs.flutter.dev/install/archive.
2. Download the latest stable Windows SDK.
3. Extract it to `C:\Users\<you>\develop\flutter`.
4. Add `C:\Users\<you>\develop\flutter\bin` to user PATH.

Restart PowerShell, then run:

```powershell
flutter doctor
```

## Android Emulator

Use Android Studio to install:

- Android SDK Platform
- Android SDK Command-line Tools
- Android Emulator
- A Pixel AVD with a recent Google APIs image

Confirm:

```powershell
flutter devices
adb devices
emulator -list-avds
```

## GitHub Repo Publish

After `gh auth login`:

```powershell
git init
git add .
git commit -m "Initial World Cup predictor app"
gh repo create worldcup-friends-predictor --public --source . --remote origin --push
```
