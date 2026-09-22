@echo off
rem Runs Everkeep with the Supabase settings from .env.
rem The values are compiled into the app, so they must be passed on every run
rem (hot reload / an already-installed build will not pick them up).
rem
rem Usage (from this folder):   run.cmd            run on the default device
rem                             run.cmd -d <id>    run on a specific device
rem                             run.cmd --release  release build
cd /d "%~dp0"
if not exist ".env" (
  echo .env not found. Copy .env.example to .env and fill in your Supabase values.
  exit /b 1
)
flutter run --dart-define-from-file=.env %*
