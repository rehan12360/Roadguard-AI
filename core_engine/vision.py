"""
RoadGuard Core Engine — Edge Detection
Runs YOLOv8 on a webcam feed, detects road hazards, and uploads
confirmed detections to the cloud backend (main.py).
"""

import cv2
from ultralytics import YOLO
import os
import requests
import time
from datetime import datetime, timezone

# ── Paths ──────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "models", "roadguard_custom.pt")

# ── Config ─────────────────────────────────────────────────
BACKEND_URL = "http://localhost:8000/api/v1/hazards/detect"
VEHICLE_ID = "car_a_detector"

# Simulated GPS for now — swap get_current_location() below for
# live GPS once the phone-relay step (GPS2IP / Share GPS) is wired up.
DEFAULT_LATITUDE = 30.7046
DEFAULT_LONGITUDE = 76.7179

LANE = "center"
COOLDOWN_SECONDS = 5          # Minimum gap between uploads
CONFIDENCE_THRESHOLD = 0.30
CRITICAL_AREA_PX = 45000      # Bounding box area threshold for "critical"


def get_current_location():
    """
    Returns (lat, lon).
    Currently hardcoded. Replace this with a request to a phone GPS
    relay (e.g. http://<phone-ip>:8080/gps) when moving to Phase 1.
    """
    return DEFAULT_LATITUDE, DEFAULT_LONGITUDE


def load_model():
    print("🔄 Initializing RoadGuard Engine...")
    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(
            f"❌ Model not found at {MODEL_PATH}\n"
            f"   Make sure roadguard_custom.pt is inside core_engine/models/"
        )
    model = YOLO(MODEL_PATH)
    print("✅ Model loaded successfully")
    print(f"   Classes: {model.names}")
    return model


def send_to_backend(hazard_type: str, confidence: float, lat: float, lon: float):
    """Send a detected hazard to the cloud backend."""
    payload = {
        "vehicle_id": VEHICLE_ID,
        "hazard_type": hazard_type,
        "confidence": round(float(confidence), 2),
        "latitude": lat,
        "longitude": lon,
        "lane": LANE,
        "severity": "high" if confidence > 0.80 else "medium",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    try:
        r = requests.post(BACKEND_URL, json=payload, timeout=3)
        data = r.json()
        if data.get("status") == "success":
            print(f"   ☁️  Uploaded → ID: {data['hazard_id']}")
            print(f"   📡 Nearby vehicles will be alerted in <2 seconds")
        else:
            print(f"   ⚠️  Backend error: {data}")
    except requests.exceptions.ConnectionError:
        print("   ❌ Backend not reachable — is main.py running?")
    except Exception as e:
        print(f"   ❌ Upload failed: {e}")


def classify_severity(area: float):
    if area > CRITICAL_AREA_PX:
        return "CRITICAL", (0, 0, 255), 3   # Red
    return "WARNING", (0, 255, 255), 2      # Yellow


def run():
    model = load_model()

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("❌ Could not open webcam")
        return

    print("\n🚀 RoadGuard Core Engine is ACTIVE")
    print("📹 Point camera at a pothole image")
    print("⌨️  Press Q to quit\n")

    last_sent_time = 0.0

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        lat, lon = get_current_location()

        results = model(frame, conf=CONFIDENCE_THRESHOLD, iou=0.45, imgsz=640, verbose=False)

        hazard_found = False
        best_class = ""
        best_confidence = 0.0

        filtered_boxes = []
        for r in results:
            for box in r.boxes:
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                conf_score = float(box.conf[0].cpu().numpy())
                class_id = int(box.cls[0].cpu().numpy())
                class_name = model.names[class_id]
                
                cx = (x1 + x2) / 2
                cy = (y1 + y2) / 2
                
                matched = False
                for fb in filtered_boxes:
                    fcx = (fb['x1'] + fb['x2']) / 2
                    fcy = (fb['y1'] + fb['y2']) / 2
                    dist = ((cx - fcx)**2 + (cy - fcy)**2)**0.5
                    if dist < 100: # 100 pixels radius
                        matched = True
                        # keep highest confidence
                        if conf_score > fb['conf']:
                            fb['x1'], fb['y1'], fb['x2'], fb['y2'] = x1, y1, x2, y2
                            fb['conf'] = conf_score
                        break
                
                if not matched:
                    filtered_boxes.append({'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'conf': conf_score, 'class_name': class_name})

        for fb in filtered_boxes:
            x1, y1, x2, y2 = fb['x1'], fb['y1'], fb['x2'], fb['y2']
            conf_score = fb['conf']
            class_name = fb['class_name']

            area = (x2 - x1) * (y2 - y1)
            tag, color, thickness = classify_severity(area)
            label = f"{tag}: {class_name} ({conf_score:.2f})"

            cv2.rectangle(frame, (int(x1), int(y1)), (int(x2), int(y2)), color, thickness)
            cv2.putText(frame, label, (int(x1), int(y1) - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

            hazard_found = True
            if conf_score > best_confidence:
                best_confidence = conf_score
                best_class = class_name

        now = time.time()
        if hazard_found and (now - last_sent_time) > COOLDOWN_SECONDS:
            print(f"\n🚨 DETECTED: {best_class.upper()}")
            print(f"   Confidence : {best_confidence:.2f} ({best_confidence * 100:.0f}%)")
            print(f"   Location   : {lat}, {lon}")
            print(f"   Sending to cloud backend...")
            send_to_backend(best_class, best_confidence, lat, lon)
            last_sent_time = now

        if hazard_found:
            hud_text = f"HAZARD: {best_class.upper()} ({best_confidence * 100:.0f}%)"
            hud_color = (0, 0, 255)
        else:
            hud_text = "SCANNING... Road Clear"
            hud_color = (0, 255, 0)

        cv2.putText(frame, hud_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, hud_color, 2)
        cv2.putText(frame, f"RoadGuard AI | Car A | {lat},{lon}",
                    (10, frame.shape[0] - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 200, 200), 1)

        cv2.imshow("RoadGuard AI — Edge Detection Engine", frame)

        if cv2.waitKey(20) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    print("\n🔒 RoadGuard Engine stopped.")


if __name__ == "__main__":
    run()
