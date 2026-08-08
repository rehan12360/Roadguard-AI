"""
RoadGuard Cloud Backend
FastAPI service that:
  - Accepts AI-detected hazards from vision.py (Car A / detector)
  - Accepts manually-reported hazards from the Flutter app
  - Serves nearby alerts (poll-based fallback; primary delivery is via
    Firestore real-time listeners directly from Flutter)
  - Handles verification, clearing, and full hazard listing
"""

from fastapi import FastAPI, HTTPException, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Literal
import firebase_admin
from firebase_admin import credentials, firestore
from math import radians, sin, cos, sqrt, atan2
from datetime import datetime, timezone
import uuid
import os
import tempfile
import cv2

# Global lazy loaded YOLO model
_yolo_model = None

def get_yolo_model():
    global _yolo_model
    if _yolo_model is None:
        try:
            from ultralytics import YOLO
            base_dir = os.path.dirname(os.path.abspath(__file__))
            model_path = os.path.join(base_dir, "..", "core_engine", "models", "roadguard_custom.pt")
            if not os.path.exists(model_path):
                model_path = os.path.join(base_dir, "..", "core_engine", "models", "yolov8n.pt")
            print(f"Loading YOLO model from: {model_path}")
            _yolo_model = YOLO(model_path)
            print("YOLO Model loaded successfully!")
        except Exception as e:
            print(f"Warning: Could not load YOLO model: {e}")
            _yolo_model = None
    return _yolo_model


import os
from supabase import create_client, Client

SUPABASE_URL = "https://ipnuxbyyphzqayguosia.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwbnV4Ynl5cGh6cWF5Z3Vvc2lhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxMzkxNjIsImV4cCI6MjEwMTcxNTE2Mn0.Z4XaIeCDxQUXWeHO19yzZKhYzyAQJaA2Z2w7KEhh_Zc"

print("Connecting to Supabase...")
db = create_client(SUPABASE_URL, SUPABASE_KEY)
print("Supabase connected successfully!")

app = FastAPI(title="RoadGuard Cloud Backend", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

COLLECTION = "prototype_hazards"
ALERT_RADIUS_M = 500


# ── Data Models ────────────────────────────────────────────
class HazardDetectPayload(BaseModel):
    """Sent by vision.py when the AI model detects a hazard."""
    vehicle_id: str
    hazard_type: str
    confidence: float = Field(ge=0.0, le=1.0)
    latitude: float
    longitude: float
    lane: str = "center"
    severity: Literal["low", "medium", "high"] = "high"
    timestamp: str


class HazardReportPayload(BaseModel):
    """Sent by the Flutter app when a user manually reports a hazard."""
    vehicle_id: str
    hazard_type: str
    latitude: float
    longitude: float
    lane: str = "unknown"
    severity: Literal["low", "medium", "high"] = "medium"
    timestamp: str


class VerifyResponse(BaseModel):
    status: str
    verifications: int | None = None
    confidence: float | None = None


# ── Helpers ────────────────────────────────────────────────
def calculate_distance(lat1, lon1, lat2, lon2) -> float:
    """Haversine distance in meters."""
    R = 6371000
    phi1, phi2 = radians(lat1), radians(lat2)
    dphi = radians(lat2 - lat1)
    dlambda = radians(lon2 - lon1)
    a = sin(dphi / 2) ** 2 + cos(phi1) * cos(phi2) * sin(dlambda / 2) ** 2
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))


def new_hazard_id() -> str:
    return f"haz_{uuid.uuid4().hex[:8]}"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# ── POST /api/v1/hazards/detect ───────────────────────────
# Called by vision.py (AI detection pipeline)
@app.post("/api/v1/hazards/detect")
async def receive_hazard(payload: HazardDetectPayload):
    hazard_id = new_hazard_id()
    doc_data = payload.dict()
    doc_data.update({
        "status": "active",
        "verifications": 1,
        "hazard_id": hazard_id,
        "source": "ai_detection",
        "created_at": utc_now_iso(),
    })

    try:
        # Prevent spamming multiple hazards for the same pothole if camera is held still
        existing_docs = list(db.table(COLLECTION).select("*").eq("status", "active").execute().data)
        for doc in existing_docs:
            h = doc.to_dict()
            if h.get("hazard_type") == payload.hazard_type:
                dist = calculate_distance(payload.latitude, payload.longitude, h.get("latitude", 0), h.get("longitude", 0))
                if dist <= 20: # 20 meters deduplication
                    new_verifications = h.get("verifications", 1) + 1
                    # Ensure confidence jumps to at least 95% on verification for demo effect
                    new_confidence = min(0.99, h.get("confidence", 0.6) + 0.05)
                    db.collection(COLLECTION).document(doc.id).update({
                        "verifications": new_verifications,
                        "confidence": round(new_confidence, 2)
                    })
                    print(f"\n✅ AI HAZARD MERGED: {payload.hazard_type.upper()} -> {doc.id}")
                    return {"status": "success", "hazard_id": doc.id, "merged": True}

        db.table(COLLECTION).insert(doc_data).execute()
        print(f"\n✅ AI HAZARD LOGGED: {payload.hazard_type.upper()}")
        print(f"   Location : {payload.latitude}, {payload.longitude}")
        print(f"   Lane     : {payload.lane}")
        print(f"   Severity : {payload.severity}")
        print(f"   ID       : {hazard_id}")
        return {"status": "success", "hazard_id": hazard_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── POST /api/v1/hazards/report ───────────────────────────
# Called by the Flutter app when a user manually taps to report
@app.post("/api/v1/hazards/report")
async def report_hazard_manual(payload: HazardReportPayload):
    hazard_id = new_hazard_id()
    doc_data = payload.dict()
    doc_data.update({
        "confidence": 1.0,  # human report = full confidence
        "status": "active",
        "verifications": 1,
        "hazard_id": hazard_id,
        "source": "manual",
        "created_at": utc_now_iso(),
    })

    try:
        db.table(COLLECTION).insert(doc_data).execute()
        print(f"\n📍 MANUAL HAZARD LOGGED: {payload.hazard_type.upper()}")
        print(f"   Reported by: {payload.vehicle_id}")
        print(f"   Location   : {payload.latitude}, {payload.longitude}")
        print(f"   ID         : {hazard_id}")
        return {"status": "success", "hazard_id": hazard_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── GET /api/v1/alerts ────────────────────────────────────
# Polling fallback — Flutter primarily uses Firestore live listeners,
# but this stays for initial load / non-Firestore clients / debugging.
@app.get("/api/v1/alerts")
async def get_alerts(vehicle_id: str, lat: float, lon: float):
    print(f"\n📡 {vehicle_id.upper()} polling for alerts...")
    try:
        hazards_ref = db.table(COLLECTION).select("*").eq("status", "active").execute().data

        nearby_alerts = []
        for doc in hazards_ref:
            h = doc.to_dict()
            h["id"] = doc.id

            if h.get("vehicle_id") == vehicle_id:
                continue

            dist = calculate_distance(lat, lon, h["latitude"], h["longitude"])
            if dist <= ALERT_RADIUS_M:
                h["distance_m"] = round(dist)
                nearby_alerts.append(h)

        print(f"   Found {len(nearby_alerts)} hazards within {ALERT_RADIUS_M}m")
        return {"alerts": nearby_alerts}

    except Exception as e:
        print(f"❌ Error: {e}")
        return {"alerts": []}


# ── POST /api/v1/verify/{hazard_id} ──────────────────────
@app.post("/api/v1/verify/{hazard_id}", response_model=VerifyResponse)
async def verify_hazard(hazard_id: str):
    ref = db.collection(COLLECTION).document(hazard_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Hazard not found")

    current = doc.to_dict()
    new_verifications = current.get("verifications", 1) + 1
    new_confidence = min(0.99, current.get("confidence", 0.6) + 0.05)
    ref.update({
        "verifications": new_verifications,
        "confidence": round(new_confidence, 2),
    })
    print(f"\n✅ VERIFIED: {hazard_id}")
    print(f"   Verifications : {new_verifications}")
    print(f"   New Confidence: {round(new_confidence * 100)}%")
    return VerifyResponse(
        status="verified",
        verifications=new_verifications,
        confidence=new_confidence,
    )


# ── POST /api/v1/process-image ─────────────────────────────
# Accepts a single image frame, runs YOLO, and returns detections
@app.post("/api/v1/process-image")
async def process_image(
    file: UploadFile = File(...),
    vehicle_id: str = Form("car_a_detector"),
    latitude: float = Form(30.7046),
    longitude: float = Form(76.7179),
):
    # Save uploaded file to temp file
    suffix = os.path.splitext(file.filename)[1] or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp_path = tmp.name
        content = await file.read()
        tmp.write(content)
        
    try:
        frame = cv2.imread(tmp_path)
        if frame is None:
            raise HTTPException(status_code=400, detail="Could not read uploaded image")

        height, width, _ = frame.shape
        model = get_yolo_model()
        detections = []
        best_hazard = None
        max_conf = 0.0

        print(f"\n📸 [IMAGE] Processing frame {width}x{height} for {vehicle_id}...")
        cv2.imwrite("latest_debug_frame.jpg", frame)

        if model is not None:
            results = model(frame, conf=0.10, verbose=False)
            for r in results:
                for box in r.boxes:
                    x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                    conf = float(box.conf[0].cpu().numpy())
                    cls_id = int(box.cls[0].cpu().numpy())
                    cls_name = model.names[cls_id]
                    
                    print(f"   => Found {cls_name} with {(conf*100):.1f}% confidence")

                    # Normalize box coordinates
                    norm_box = {
                        "label": cls_name,
                        "confidence": round(conf, 2),
                        "x1": round(float(x1) / width, 4),
                        "y1": round(float(y1) / height, 4),
                        "x2": round(float(x2) / width, 4),
                        "y2": round(float(y2) / height, 4),
                    }
                    detections.append(norm_box)

                    if conf > max_conf:
                        max_conf = conf
                        best_hazard = {
                            "type": cls_name if cls_name in ["pothole", "road_damage", "waterlogging"] else "pothole",
                            "conf": conf,
                        }

        # If any hazard detected, log it (allow low confidence to be verified later)
        if best_hazard and best_hazard["conf"] > 0.10:
            existing_docs = list(db.table(COLLECTION).select("*").eq("status", "active").execute().data)
            matched_id = None
            
            for doc in existing_docs:
                h = doc
                if calculate_distance(latitude, longitude, h.get("latitude", 0), h.get("longitude", 0)) <= 20:
                    matched_id = h.get("hazard_id")
                    current_conf = h.get("confidence", 0.6)
                    break
                    
            if matched_id:
                new_conf = min(0.99, current_conf + 0.05)
                # fetch current verifications
                # for now just bump it in Supabase
                try:
                    res = db.table(COLLECTION).select("verifications").eq("hazard_id", matched_id).execute()
                    current_verifs = res.data[0].get("verifications", 1) if res.data else 1
                    db.table(COLLECTION).update({
                        "verifications": current_verifs + 1,
                        "confidence": round(new_conf, 2)
                    }).eq("hazard_id", matched_id).execute()
                except Exception as e:
                    print("Error updating Supabase:", e)
            else:
                hazard_id = new_hazard_id()
                try:
                    db.table(COLLECTION).insert({
                        "vehicle_id": vehicle_id,
                        "hazard_type": best_hazard["type"],
                        "confidence": round(best_hazard["conf"], 2),
                        "latitude": latitude,
                        "longitude": longitude,
                        "lane": "center",
                        "severity": "high" if best_hazard["conf"] > 0.80 else "medium",
                        "timestamp": utc_now_iso(),
                        "status": "active",
                        "verifications": 1,
                        "hazard_id": hazard_id,
                        "source": "hybrid_edge_ai",
                        "created_at": utc_now_iso(),
                    }).execute()
                except Exception as e:
                    print("Error inserting to Supabase:", e)

        return {
            "status": "success",
            "frame_width": width,
            "frame_height": height,
            "detections": detections,
            "best_hazard": best_hazard,
        }

    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


# ── POST /api/v1/process-video ─────────────────────────────
# Accepts video file upload, runs YOLO model frame-by-frame,
# logs detected hazards into Firestore, and returns bounding box metadata.
@app.post("/api/v1/process-video")
async def process_video(
    file: UploadFile = File(...),
    vehicle_id: str = Form("car_a_detector"),
    latitude: float = Form(30.7046),
    longitude: float = Form(76.7179),
):
    print(f"\n[VIDEO] RECEIVED VIDEO UPLOAD: {file.filename} from {vehicle_id}")
    
    # Save uploaded file to temp file
    suffix = os.path.splitext(file.filename)[1] or ".mp4"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp_path = tmp.name
        content = await file.read()
        tmp.write(content)
        
    try:
        cap = cv2.VideoCapture(tmp_path)
        if not cap.isOpened():
            raise HTTPException(status_code=400, detail="Could not read uploaded video file")

        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = int(cap.get(cv2.CAP_PROP_FPS)) or 30

        print(f"   Video Specs: {width}x{height} @ {fps}fps, Total Frames: {total_frames}")

        model = get_yolo_model()
        detections = []
        created_hazards = []
        frame_idx = 0
        sample_step = max(1, fps // 6) # Sample ~6 frames per second for smooth AI speed

        best_hazard = None
        max_conf = 0.0

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            if frame_idx % sample_step == 0 and model is not None:
                # Run YOLO inference
                results = model(frame, conf=0.30, verbose=False)
                for r in results:
                    for box in r.boxes:
                        x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                        conf = float(box.conf[0].cpu().numpy())
                        cls_id = int(box.cls[0].cpu().numpy())
                        cls_name = model.names[cls_id]

                        # Normalize box coordinates
                        norm_box = {
                            "frame": frame_idx,
                            "timestamp_ms": int((frame_idx / fps) * 1000),
                            "label": cls_name,
                            "confidence": round(conf, 2),
                            "x1": round(float(x1) / width, 4),
                            "y1": round(float(y1) / height, 4),
                            "x2": round(float(x2) / width, 4),
                            "y2": round(float(y2) / height, 4),
                            "lane": "center",
                        }
                        detections.append(norm_box)

                        if conf > max_conf:
                            max_conf = conf
                            best_hazard = {
                                "type": cls_name if cls_name in ["pothole", "road_damage", "waterlogging"] else "pothole",
                                "conf": conf,
                            }

            frame_idx += 1

        cap.release()

        # Cluster bounding boxes (Spatio-Temporal NMS)
        final_detections = []
        for d in detections:
            d_cx = (d["x1"] + d["x2"]) / 2
            d_cy = (d["y1"] + d["y2"]) / 2
            
            matched = False
            for f in final_detections:
                f_cx = (f["x1"] + f["x2"]) / 2
                f_cy = (f["y1"] + f["y2"]) / 2
                
                time_diff_sec = abs(d["frame"] - f.get("frame", 0)) / float(fps)
                dist = ((d_cx - f_cx)**2 + (d_cy - f_cy)**2)**0.5
                
                # If they appear within 2.5 seconds of each other AND are within a 15% spatial radius 
                # (which allows the pothole to move down the screen as the car drives), merge them.
                if time_diff_sec <= 2.5 and time_diff_sec > 0 and dist < 0.15:
                    matched = True
                    # Keep the bounding box with the highest confidence
                    if d["confidence"] > f["confidence"]:
                        f["confidence"] = d["confidence"]
                        f["x1"] = d["x1"]
                        f["y1"] = d["y1"]
                        f["x2"] = d["x2"]
                        f["y2"] = d["y2"]
                        f["frame"] = max(f["frame"], d["frame"])
                    else:
                        f["frame"] = max(f["frame"], d["frame"])
                    break
            if not matched:
                final_detections.append(d)
                
        detections = final_detections

        if not best_hazard or best_hazard["conf"] <= 0.10:
            print("✅ VIDEO PROCESSED: No hazards detected above threshold.")
            return {
                "status": "no_hazard_found",
                "video": file.filename,
                "message": "No hazards detected with > 10% confidence."
            }

        # Log ALL detected hazards to Firestore
        created_hazards_list = []
        
        # We need a small GPS offset because the payload only provides one lat/lon for the whole video.
        # If we log 3 hazards at the exact same lat/lon, they will overlap entirely on the map.
        offset_step = 0.00015 # approx 15 meters
        
        existing_hazards_docs = list(db.table(COLLECTION).select("*").eq("status", "active").execute().data)
        
        for idx, d in enumerate(detections):
            d_lat = latitude + (idx * offset_step)
            d_lon = longitude + (idx * offset_step)
            
            matched_hazard_id = None
            current_conf = 0.0
            current_verifications = 0
            
            for doc in existing_hazards_docs:
                h = doc.to_dict()
                if calculate_distance(d_lat, d_lon, h.get("latitude", 0), h.get("longitude", 0)) <= 20:
                    matched_hazard_id = doc.id
                    current_conf = h.get("confidence", 0.6)
                    current_verifications = h.get("verifications", 1)
                    break
                    
            if matched_hazard_id:
                new_verifications = current_verifications + 1
                new_confidence = min(0.99, current_conf + 0.05)
                db.collection(COLLECTION).document(matched_hazard_id).update({
                    "verifications": new_verifications,
                    "confidence": round(new_confidence, 2),
                })
                created_hazards_list.append({
                    "id": matched_hazard_id,
                    "type": d["label"],
                    "conf": round(new_confidence, 2)
                })
            else:
                hazard_id = new_hazard_id()
                doc_data = {
                    "vehicle_id": vehicle_id,
                    "hazard_type": d["label"],
                    "confidence": round(d["confidence"], 2),
                    "latitude": d_lat,
                    "longitude": d_lon,
                    "lane": "center",
                    "severity": "high" if d["confidence"] > 0.80 else "medium",
                    "timestamp": utc_now_iso(),
                    "status": "active",
                    "verifications": 1,
                    "hazard_id": hazard_id,
                    "source": "video_ai_detection",
                    "created_at": utc_now_iso(),
                }
                db.table(COLLECTION).insert(doc_data).execute()
                existing_hazards_docs.append(db.table(COLLECTION).select("*").eq("hazard_id", hazard_id).execute()) # prevent immediate self-merging
                created_hazards_list.append({
                    "id": hazard_id,
                    "type": d["label"],
                    "conf": round(d["confidence"], 2)
                })

        print(f"✅ VIDEO PROCESSED: {len(detections)} detection frames found.")
        print(f"   Logged {len(created_hazards_list)} Hazards to Firestore.")

        return {
            "status": "success",
            "video": file.filename,
            "frame_width": width,
            "frame_height": height,
            "total_frames": total_frames,
            "fps": fps,
            "detections": detections,
            "primary_hazard_id": created_hazards_list[0]["id"] if created_hazards_list else None,
            "hazard_type": created_hazards_list[0]["type"] if created_hazards_list else "pothole",
            "confidence": created_hazards_list[0]["conf"] if created_hazards_list else 0.0,
            "all_hazards": created_hazards_list,
            "verifications": 1,
            "latitude": latitude,
            "longitude": longitude,
        }

    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


# ── GET /api/v1/vehicles ──────────────────────────────────
# Pre-configured vehicle locations for demo
@app.get("/api/v1/vehicles")
async def get_preset_vehicles():
    return {
        "vehicles": [
            {
                "id": "car_a_detector",
                "name": "Car A (Detection Vehicle)",
                "role": "detector",
                "latitude": 30.7046,
                "longitude": 76.7179,
                "status": "Scanning / Video AI",
                "distance_m": 0,
            },
            {
                "id": "car_b_near",
                "name": "Car B (Driver - 250m Ahead)",
                "role": "alerted",
                "latitude": 30.7065,
                "longitude": 76.7185,
                "status": "Alerted (< 500m)",
                "distance_m": 250,
            },
            {
                "id": "car_c_near",
                "name": "Car C (Driver - 420m Ahead)",
                "role": "alerted",
                "latitude": 30.7080,
                "longitude": 76.7195,
                "status": "Alerted (< 500m)",
                "distance_m": 420,
            },
            {
                "id": "car_d_far",
                "name": "Car D (Driver - 850m Out)",
                "role": "out_of_scope",
                "latitude": 30.7120,
                "longitude": 76.7250,
                "status": "Clear (> 500m)",
                "distance_m": 850,
            },
        ]
    }


# ── DELETE /api/v1/hazards/{hazard_id} ────────────────────
# Mark a single hazard resolved/cleared (e.g. pothole got fixed)
@app.delete("/api/v1/hazards/{hazard_id}")
async def clear_one(hazard_id: str):
    ref = db.collection(COLLECTION).document(hazard_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Hazard not found")
    ref.update({"status": "cleared"})
    print(f"\n🗑️  Cleared hazard {hazard_id}")
    return {"status": "cleared", "hazard_id": hazard_id}


# ── DELETE /api/v1/clear ──────────────────────────────────
# Resets all hazards for demo restart
@app.delete("/api/v1/clear")
@app.post("/api/v1/demo/reset")
async def clear_all():
    docs = db.collection(COLLECTION).stream()
    count = 0
    for doc in docs:
        doc.reference.delete()
        count += 1
    print(f"\n🗑️  Cleared {count} hazards from database")
    return {"status": "cleared", "deleted": count}


# ── GET /api/v1/hazards ───────────────────────────────────
# Returns all active hazards (for map dashboard / debugging)
@app.get("/api/v1/hazards")
async def get_all_hazards():
    docs = db.table(COLLECTION).select("*").eq("status", "active").execute().data
    return {"hazards": [doc.to_dict() for doc in docs]}


# ── GET /health ────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "service": "RoadGuard Backend"}

