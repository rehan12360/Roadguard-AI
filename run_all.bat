@echo off
title RoadGuard AI Launcher
echo =========================================
echo       Starting RoadGuard AI Prototype
echo =========================================

echo.
echo [1/3] Starting Cloud Backend (FastAPI) on Port 8000...
start "RoadGuard Backend" cmd /k "cd cloud_backend && uvicorn main:app --host 0.0.0.0 --port 8000 --reload"

echo [2/3] Starting Flutter Application...
start "RoadGuard Flutter UI" cmd /k "cd flutter_app && flutter run"

echo [3/3] Starting Edge AI Detector (Webcam)...
start "RoadGuard Edge AI" cmd /k "cd core_engine && python vision.py"

echo.
echo All services have been launched in separate command windows.
echo You can test the app using the 'DEMO CLIP' button inside the Flutter app!
echo =========================================
pause
