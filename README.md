<div align="center">

# 🚨 <span style="color:#FF4B4B">RoadGuard</span> <span style="color:#00B4D8">AI</span> 🛡️

<a href="https://github.com/rehan12360/Roadguard-AI">
  <img src="https://readme-typing-svg.demolab.com?font=Orbitron&weight=800&size=35&pause=1000&color=00B4D8&center=true&vCenter=true&width=900&height=80&lines=Autonomous+Road+Hazard+Intelligence;Decentralized+Edge-to-Cloud+Network;One+Vehicle+Detects.+Every+Vehicle+Benefits." alt="Typing SVG" />
</a>

<br>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI"/>
  <img src="https://img.shields.io/badge/Ultralytics_YOLOv8-FF4B4B?style=for-the-badge&logo=pytorch&logoColor=white" alt="YOLOv8"/>
  <img src="https://img.shields.io/badge/OpenCV-5C3EE8?style=for-the-badge&logo=opencv&logoColor=white" alt="OpenCV"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase"/>
  <img src="https://img.shields.io/badge/Python_3.10-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python"/>
</p>

### 🌍 Transforming every ordinary vehicle into an autonomous road safety sentinel.

<img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" width="800">

</div>

<br>

## 📌 Problem Statement

> ⚠️ **The Critical Flaw in Modern Navigation** <br>
> Waze and Google Maps rely entirely on **manual, highly distracting, and delayed driver input**. Hazards are reported reactively, often miles behind their actual physical location. 

Potholes, sudden waterlogging, and road debris cause billions in vehicle damage and contribute to countless accidents annually. Our current data collection infrastructure remains dangerously slow, fundamentally manual, and incapable of providing the split-second, hyper-local awareness required to prevent accidents before they happen.

<br>

<div align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=20&pause=1000&color=FF4B4B&background=111111&center=true&vCenter=true&width=600&lines=System+Online...;Initializing+Edge+AI+Nodes...;Geofence+Active+and+Scanning..." alt="Console SVG" />
</div>

<br>

## 💡 The Solution

RoadGuard AI fundamentally reimagines road safety by deploying a **hybrid Edge-to-Cloud architecture** that transforms every ordinary vehicle into an autonomous, mobile road inspection unit. 

<table>
  <tr>
    <td><img src="https://img.icons8.com/color/96/000000/artificial-intelligence.png" width="50"></td>
    <td><b>1. Edge AI Inference</b><br>We deploy a custom-trained YOLOv8n computer vision model directly to vehicle dashcams to detect hazards in real-time at 30 FPS.</td>
  </tr>
  <tr>
    <td><img src="https://img.icons8.com/color/96/000000/api-settings.png" width="50"></td>
    <td><b>2. Ultra-Light Payloads</b><br>Instead of streaming heavy, latency-prone video, the edge client processes frames locally and transmits a sub-200-byte JSON payload.</td>
  </tr>
  <tr>
    <td><img src="https://img.icons8.com/color/96/000000/radar.png" width="50"></td>
    <td><b>3. Spatio-Temporal WebSockets</b><br>The cloud instantly utilizes the Haversine spherical distance formula to push real-time WebSocket alerts strictly to trailing vehicles within a 500-meter geofence.</td>
  </tr>
</table>

<br>
<img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/solar.png" width="100%">
<br>

## 🏗️ System Architecture

Our system utilizes a highly optimized Edge-to-Cloud pipeline to minimize latency and preserve bandwidth.

```mermaid
graph TD
    subgraph EdgeLayer ["🚗 Edge AI Node (Car A)"]
        Cam["Dashcam 30 FPS"] --> YOLO["YOLOv8n Inference"]
        YOLO -->|"Severity Classification"| Cooldown["Temporal Cooldown Logic"]
        Cooldown -->|"Sub-200-Byte JSON Payload"| Net["Cellular Network"]
    end

    subgraph CloudLayer ["☁️ FastAPI Backend"]
        Net --> API["POST /api/v1/hazards/detect"]
        API --> NMS["Spatio-Temporal NMS Deduplication"]
        NMS --> DB[("Firebase Firestore")]
        DB -->|"Real-time WebSockets"| Geo["Haversine Geofence Engine"]
    end

    subgraph ClientLayer ["📱 Trailing Vehicles (Cars B & C)"]
        Geo -->|"500m Radius Match"| App1["Flutter Dashboard"]
        Geo -->|"500m Radius Match"| App2["Pyttsx3 TTS Audio Warning"]
        App1 --> Verify["Crowd Consensus Auto-Verification"]
        App2 --> Verify
        Verify -.->|"Update Confidence Score"| DB
    end
    
    style EdgeLayer fill:#f9f9f9,stroke:#333,stroke-width:2px
    style CloudLayer fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    style ClientLayer fill:#f1f8e9,stroke:#558b2f,stroke-width:2px
```

<br>

## 🧠 Core Algorithms

### 📡 1. Spatio-Temporal NMS (Non-Maximum Suppression)
Solves the "map flooding" problem. Edge AI detecting a pothole over 120 frames would normally spam a database. Our cloud backend mathematically clusters and deduplicates reports using strict temporal deltas (2.5s rolling windows) and Euclidean spatial distance tracking on normalized bounding boxes.

### 🤝 2. Crowd Consensus Verification
To combat Edge AI false positives (like misclassifying a shadow), we engineered a self-healing consensus algorithm. When trailing cars physically cross the exact GPS coordinates of a hazard, the system autonomously triggers a verification ping, escalating the confidence score (e.g., `0.92 -> 0.97 -> 0.99`).

### 🌐 3. Hyper-Targeted Haversine Geofencing
Alerts are restricted strictly to vehicles within a 500-meter radius, factoring in relative heading and lane positioning, utilizing the Haversine formula based on the Earth's radius:
> `Distance = 2 * R * atan2(√a, √(1-a))`

<br>
<img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/solar.png" width="100%">
<br>

## 🚀 What You Will See in the Demo

| 🚘 Vehicle | 📍 Distance | 🔔 Alert Received? | 🤖 System Action |
|---------|----------|-----------------|---------------|
| **Car A** | Origin | N/A | Detects hazard & uploads JSON to cloud |
| **Car B** | 300m | ✅ **YES** | Triggers audio: Move right & reduce speed |
| **Car C** | 250m | ✅ **YES** | Triggers audio: Already in safe lane |
| **Car D** | 800m | ❌ **NO** | Outside 500m Haversine radius (ignored) |

As **Car B** and **Car C** drive over the coordinates, the confidence mathematically scales: **0.92 → 0.97 → 0.99**.

<br>

## ⚙️ How To Run (Local Demo)

<details>
<summary><b>Click to reveal setup instructions</b></summary>
<br>

### Step 1 — Start the Backend
```bash
cd cloud_backend
# Activate environment (e.g., env_cloud\Scripts\activate)
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Step 2 — Start Car A (Detection Engine)
```bash
cd core_engine
# Activate environment
python vision.py
```

### Step 3 — Run Flutter App on Phone
```bash
cd flutter_app
flutter run
```
</details>

<br>

<div align="center">
  <img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" width="800">
  <p><i>Built for the Future of Smart Cities and V2X Communication.</i></p>
</div>