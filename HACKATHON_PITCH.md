# 🛡️ RoadGuard AI — Comprehensive Hackathon Pitch & Deep Architecture Guide

> **Elevator Pitch:** RoadGuard AI turns every vehicle into an autonomous mobile road inspection unit. When one vehicle detects a road hazard, every vehicle within 500 meters is alerted in under 2 seconds — with **zero manual driver reporting**.

This document serves as your complete technical reference for judges. It covers the high-level architecture, math formulas, spatio-temporal logic, and the detailed breakdown of the codebase components.

---

## 🏗️ 1. Complete System Architecture & Data Flow

RoadGuard AI operates on a hybrid **Edge-to-Cloud architecture**, maximizing speed while keeping cloud costs low. 

![Connected Vehicles Architecture](C:\Users\mreha\.gemini\antigravity-ide\brain\d191550a-b765-4020-9396-0f21189695a1\connected_vehicles_architecture_1786074968299.png)

### The 4 Pillars of the Codebase:
1. **`core_engine/` (Edge AI Layer):** 
   Runs the `vision.py` script. This represents a vehicle's dashcam. It uses a custom-trained YOLOv8n model to detect potholes, waterlogging, or debris in real-time. It only sends lightweight metadata (JSON) to the cloud when a hazard is found, saving bandwidth.
2. **`cloud_backend/` (FastAPI Cloud Engine):** 
   The `main.py` service. It processes incoming detections, runs spatial matching algorithms, and executes Spatio-Temporal Non-Maximum Suppression (NMS) on uploaded dashcam videos.
3. **Firebase Firestore (Real-Time Database):** 
   The glue that holds the system together. Hazards are written to the `prototype_hazards` collection. The database uses real-time WebSockets to instantly broadcast state changes to active drivers.
4. **`client_apps/` & `flutter_app/` (Driver Interfaces):** 
   Represents trailing vehicles (Car B, Car C). They maintain active geofences and trigger audio/visual warnings. The Python receivers use `pyttsx3` for text-to-speech, while the Flutter app provides a full map dashboard with live bounding box overlays.

---

## 📷 2. Autonomous Edge Detection Deep Dive (Car A)

Instead of relying on drivers to tap a button on their phone (which is dangerous and slow), RoadGuard AI is completely autonomous. 

![Edge AI Dashcam POV](C:\Users\mreha\.gemini\antigravity-ide\brain\d191550a-b765-4020-9396-0f21189695a1\dashcam_pothole_detection_1786074958848.png)

### How `core_engine/vision.py` Works:
1. **Inference Loop:** The camera is scanned at 30 FPS. YOLOv8 runs inference at `imgsz=640` with a strict `0.60` confidence threshold.
2. **Dynamic Severity Classification:** The system calculates the area of the bounding box:
   `Area = (x2 - x1) * (y2 - y1)`
   If the area is $> 45000\text{px}$, the hazard is flagged as **CRITICAL** (Red UI). Otherwise, it's flagged as **WARNING** (Yellow UI).
3. **Cooldown Logic:** To prevent API spam, a `COOLDOWN_SECONDS = 5` logic block ensures that even if a pothole is in frame for 4 seconds, only *one* network request is fired to the backend.

---

## 🧠 3. Advanced Backend Algorithms (`cloud_backend/main.py`)

When the backend receives hazard data, it runs sophisticated math to ensure the data is actionable.

### Spatio-Temporal NMS (Non-Maximum Suppression)
When a driver uploads a dashcam clip (e.g., to `/api/v1/process-video`), the video contains hundreds of frames of the *same* pothole. If we logged every frame, the map would be flooded. 
The backend clusters them by looking at:
1. **Time Delta:** Are the frames within a `2.5-second` window?
2. **Spatial Delta:** The Euclidean distance between normalized bounding box centers $(C_x, C_y)$ is calculated:
   $D = \sqrt{(C_{x1} - C_{x2})^2 + (C_{y1} - C_{y2})^2}$
   If $D < 0.15$ (15% screen shift allowed for vehicle motion), they are treated as the **same pothole**. The backend merges them and retains only the box with the highest confidence.

### The Haversine Geodesic Formula
To determine exactly which trailing cars should receive an alert, the system calculates the spherical distance between the hazard and the trailing vehicles using the Earth's radius ($R = 6371000$ meters):

$$a = \sin^2\left(\frac{\Delta \text{lat}}{2}\right) + \cos(\text{lat}_1) \cos(\text{lat}_2) \sin^2\left(\frac{\Delta \text{lon}}{2}\right)$$
$$\text{Distance} = 2 \cdot R \cdot \text{atan2}\left(\sqrt{a}, \sqrt{1-a}\right)$$

If the distance is $\le 500\text{m}$, the alert payload is delivered.

---

## 🚨 4. Real-Time Distribution & Crowd Verification

Once the backend approves the hazard, it broadcasts it.

![Flutter Driver Dashboard](C:\Users\mreha\.gemini\antigravity-ide\brain\d191550a-b765-4020-9396-0f21189695a1\flutter_dashboard_alert_1786075047401.png)

### The Geofence Experience (Cars B, C, & D)
- **Car B (300m away, same lane):** The script `car_b_receiver.py` trips the 500m geofence. In under 2 seconds, the `pyttsx3` engine announces: *"Warning! Pothole ahead. 300 meters. Move right and reduce speed."*
- **Car C (250m away, right lane):** Receives the alert, but is advised that their current lane is safe.
- **Car D (800m away):** Receives nothing. Demonstrates the strict 500m logic.

### Confidence Escalation (Consensus)
Edge AI can make mistakes (e.g., mistaking a shadow for a pothole). To fix this, RoadGuard AI uses **Crowd Consensus**.
When Car B physically crosses the GPS coordinates of the pothole, it triggers `POST /api/v1/verify/{hazard_id}`. 

The backend applies a math formula to escalate the hazard's confidence score, proving to the network that the hazard is real:
$$\text{New Confidence} = \min(0.99, \, \text{Old Confidence} + 0.05)$$
Thus, a $0.92$ confidence detection becomes $0.97$, and then $0.99$ as more cars pass by.

---

## 🚀 5. Presentation Playbook for Judges

If a judge asks **"Why not just use Waze?"**, your answer is:
> *"Waze requires a driver to take their hands off the wheel, look at their phone, and tap three buttons to report a pothole. By the time they do that, the pothole is 2 miles behind them. RoadGuard AI uses Edge AI to detect it instantly and autonomously, meaning the car 300 meters behind you gets a warning before they even see the hazard."*

If a judge asks **"Doesn't video streaming cost too much data?"**, your answer is:
> *"We don't stream video to the cloud! The AI inference runs locally on the dashcam (Edge AI). We only send a 200-byte JSON payload containing the GPS coordinates and the hazard type. We only process video in the cloud for diagnostic dashcam uploads, where we use our Spatio-Temporal NMS algorithm to prevent duplicate entries."*
