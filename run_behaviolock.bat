@echo off
title BehavioLock Startup script
echo Starting BehavioLock...

:: 1. Start the Flask Backend in a new dedicated Command Prompt window
echo Starting Python Flask Backend...
start "BehavioLock Backend Server" cmd /k "cd flask_backend & call venv\Scripts\activate & python app.py"

:: 2. Wait a couple of seconds to ensure backend is running before frontend starts
timeout /t 3 /nobreak > nul

:: 3. Start the Flutter Web App in the current window using Chrome
echo Starting Flutter Frontend...
cd KeyStroke_Bank
flutter run -d chrome --web-port=8080
