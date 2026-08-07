# 🛡️ RoadGuard AI
### Crowd-Powered Edge AI Road Hazard Intelligence Network
> One Vehicle Detects. Every Vehicle Benefits.

---

## What It Does
RoadGuard AI turns every vehicle into a mobile road inspection unit.
When one vehicle detects a hazard, every vehicle within 500m is
automatically alerted in under 2 seconds — with zero manual reporting.

---

## Project Structure
ROADGUARD-PROTOTYPE/
├── cloud_backend/      FastAPI backend + Firebase
├── core_engine/        YOLOv8 detection engine (Car A)
└── client_apps/        Alert receivers (Cars B, C, D)

---

## How To Run (4-Car Demo)

### Step 1 — Start the backend
```bash
cd cloud_backend
env_cloud\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Step 2 — Start Car A detection engine
```bash
cd core_engine
env_prototype\Scripts\activate
python vision.py
```

### Step 3 — Start Car B (same lane, 300m behind)
```bash
cd client_apps
python car_b_receiver.py
```

### Step 4 — Start Car C (right lane, 250m behind)
```bash
cd client_apps
python car_c_receiver.py
```

### Step 5 — Start Car D (800m away, outside radius)
```bash
cd client_apps
python car_d_receiver.py
```

---

## What You Will See
| Vehicle | Distance | Alert? | Action |
|---------|----------|--------|--------|
| Car A | Origin | Detects hazard | Uploads to cloud |
| Car B | 300m | ✅ YES | Move right |
| Car C | 250m | ✅ YES | Already safe lane |
| Car D | 800m | ❌ NO | Outside radius |

Confidence climbs: **0.92 → 0.97 → 0.99**
as Car B and Car C verify the hazard.

---

## Tech Stack
- **Edge AI:** YOLOv8n (custom trained)
- **Backend:** FastAPI + Python
- **Database:** Firebase Firestore
- **Geo Logic:** Haversine distance formula
- **Voice Alerts:** pyttsx3 (speaks through speakers)

---
                    ┌─────────────────┐
                    │   WEBCAM (Car A)│
                    │  vision.py runs │
                    │  YOLOv8 model   │
                    └────────┬────────┘
                             │ detects pothole
                             │ POST /api/v1/hazards/detect
                             ▼
                    ┌─────────────────┐
                    │  CLOUD BACKEND  │
                    │   main.py       │
                    │  FastAPI server │
                    │  Firebase store │
                    └──┬──────────┬───┘
                       │          │
          ┌────────────┘          └────────────┐
          │ GET /alerts                        │ GET /alerts
          │ (every 3s)                         │ (every 3s)
          ▼                                    ▼
┌──────────────────┐               ┌──────────────────┐
│ car_b_receiver   │               │ car_c_receiver   │
│ 300m behind      │               │ 250m right lane  │
│ ✅ GETS ALERT    │               │ ✅ GETS ALERT    │
│ Auto-verifies    │               │ Behaviour verify │
│ Confidence: 0.97 │               │ Confidence: 0.99 │
└──────────────────┘               └──────────────────┘

                    ┌──────────────────┐
                    │ car_d_receiver   │
                    │ 800m away        │
                    │ ❌ NO ALERT      │
                    │ Proves radius    │
                    │ boundary works   │
                    └──────────────────┘

## Team
[Your team name] | [College Name] | InnoVent-27