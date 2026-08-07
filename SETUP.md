# RoadGuard AI — Comprehensive Phone & Pitch Demo Setup Guide

This guide provides step-by-step instructions for running the **RoadGuard AI Pitch Demo** on a physical mobile phone (or multiple devices/emulators) connected to your local laptop backend.

---

## 📋 Prerequisites Checklist

Before beginning, ensure you have installed:
- [x] **Flutter SDK** (v3.0.0 or higher) with Android SDK tools.
- [x] **Python** (v3.9 or higher).
- [x] **Android Mobile Phone** (Developer Mode & USB Debugging enabled) OR Android Emulator.
- [x] **Laptop & Phone connected to the SAME Wi-Fi network**.

---

## 🌐 Step 1: Find Your Laptop's Local IP Address

To allow your phone to communicate with the Python backend running on your laptop:

1. Open a terminal / command prompt on your laptop:
   - **Windows**: Run `ipconfig` -> Look for **IPv4 Address** (e.g. `192.168.1.42` or `192.168.137.1`).
   - **Mac/Linux**: Run `ifconfig` or `ip addr` -> Look for `inet 192.168.x.x`.

2. Open `flutter_app/lib/services/api_service.dart` in your code editor.
3. Update the `baseUrl` with your laptop's IP address (keep port `:8000`):
   ```dart
   // Example:
   static const String baseUrl = 'http://192.168.1.42:8000';
   ```

---

## 🐍 Step 2: Start the Cloud Backend & YOLO AI Engine

1. Open terminal on your laptop and navigate to `cloud_backend`:
   ```bash
   cd f:\roadguard-prototype\cloud_backend
   ```

2. (Optional) Activate your Python virtual environment if using one:
   ```bash
   # Windows PowerShell:
   .\env_cloud\Scripts\activate
   ```

3. Install required Python packages (if not already installed):
   ```bash
   pip install -r requirements.txt
   ```

4. Launch the FastAPI backend bound to `--host 0.0.0.0` (allows external phone connections):
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```
   > 🟢 **Verification**: You should see:
   > `INFO: Application startup complete.`
   > `INFO: Uvicorn running on http://0.0.0.0:8000`

---

## 📱 Step 3: Flutter App Setup & Permissions

1. Open a second terminal window and navigate to `flutter_app`:
   ```bash
   cd f:\roadguard-prototype\flutter_app
   ```

2. Fetch all required packages (`video_player`, `image_picker`, `google_maps_flutter`, `flutter_tts`, `provider`):
   ```bash
   flutter pub get
   ```

3. Verify Android permissions in `flutter_app/android/app/src/main/AndroidManifest.xml`:
   Ensure the following lines exist inside `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
   <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
   ```

---

## 📲 Step 4: Run the App on Your Phone

1. Connect your Android phone to your laptop via USB cable.
2. Verify Flutter detects your phone:
   ```bash
   flutter devices
   ```
   > You will see your phone listed (e.g., `SM-G998B (mobile)`).

3. Launch the app directly on your phone:
   ```bash
   flutter run -d <your-device-id>
   ```
   *(Or run `flutter run` and select your connected phone from the list).*

   *(Optional Release APK)*: If you want to install an APK file on your phone without keeping it tethered to USB:
   ```bash
   flutter build apk --release
   ```
   The generated file will be at `flutter_app/build/app/outputs/flutter-apk/app-release.apk`. Transfer and install it on your phone.

---

## 🚀 Step 5: Live Pitch Demo Execution (Step-by-Step)

Follow this exact sequence during your presentation or live demo:

### 1️⃣ Step 5.1 — Detector Mode (Car A)
1. Open the app on the phone.
2. On **Screen 1 (Setup)**, tap **Car A — AI Detection Car**, then tap **START VIDEO AI SCANNER**.
3. You will be taken to **Screen 2 (Video AI)**.
4. Tap **DEMO CLIP** (or tap **UPLOAD ROAD VIDEO** to pick any road clip from your phone gallery).
5. **Watch the AI work**:
   - The dashcam video plays with cyan lane overlays.
   - Bounding boxes appear over potholes with real-time confidence scores (e.g. `pothole: 94%`).
   - A green toast appears: **"Hazard Logged & Uploaded ✅"**.

### 2️⃣ Step 5.2 — Geofenced Radar Map
1. Tap the **Radar Map** tab in the bottom navigation bar.
2. See all 4 cars (Car A, B, C, D) on Google Maps.
3. Observe the **red 500m geofence circle** centered around Car A and the newly dropped hazard marker.

### 3️⃣ Step 5.3 — Incoming Alert & Voice TTS (Car B - 250m Ahead)
1. Tap the **Setup** tab and select **Car B — Driver (250m Ahead)**.
2. Tap the **Alert HUD** tab.
3. **Listen & Watch**:
   - The phone's speaker automatically announces: *"Warning! Pothole detected 250 meters ahead in Center Lane!"*
   - A pulsing emergency alert card appears displaying **250m distance** and safety instructions (*"Slow down & steer right"*).
4. Tap the **VERIFY HAZARD** button.
   - Watch the live network confidence score climb from `92% -> 97% -> 99%`.

### 4️⃣ Step 5.4 — Out of Scope Verification (Car D - 850m Out)
1. Tap **Setup** and select **Car D — Driver (850m Out)**.
2. Tap **Alert HUD**.
3. Notice that the screen remains green and calm: *"ROAD CLEAR — Vehicle is > 500m outside active hazard radius"*. This proves your 500m geofence filtering works perfectly.

### 5️⃣ Step 5.5 — Hackathon Pitch Stats & Reset
1. Tap **Pitch Stats** to view live metrics (Total Hazards, Alerts Sent, Verifications, Network Latency < 0.8s).
2. Tap **RESET DEMO ENVIRONMENT** to clear all hazards and reset state for your next presentation!

---

## 🛠️ Troubleshooting

| Issue | Solution |
| :--- | :--- |
| **Phone says "Backend not reachable"** | Ensure phone and laptop are on the **same Wi-Fi**. Verify laptop IP in `lib/services/api_service.dart`. Check laptop Firewall (allow port 8000). |
| **Google Maps displays blank grid** | Ensure Google Maps API key is configured in `AndroidManifest.xml`. |
| **No Voice Speech output** | Ensure phone media/ring volume is turned UP and Text-to-Speech (TTS) engine is enabled in phone settings. |
| **Video upload fails** | Verify backend terminal displays `INFO: 192.168.x.x - "POST /api/v1/process-video" 200 OK`. |
