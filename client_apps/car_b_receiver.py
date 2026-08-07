import requests
import time
import pyttsx3

CLOUD_URL  = "http://localhost:8000/api/v1/alerts"
VERIFY_URL = "http://localhost:8000/api/v1/verify"

# Car B position — 300m behind Car A
CAR_B = {
    "vehicle_id": "car_b_follower",
    "lat": 30.7019,
    "lon": 76.7179
}

# Text to speech engine
engine = pyttsx3.init()
engine.setProperty('rate', 150)

def speak(text):
    try:
        engine.say(text)
        engine.runAndWait()
    except:
        pass  # Skip TTS if not available

print("=" * 55)
print("   🚗 CAR B DASHBOARD — INITIALIZED")
print("   Position : 300m behind Car A (same lane)")
print("   Radius   : 500m alert zone")
print("=" * 55)
print("Scanning for hazards...\n")

alerted_ids = set()

while True:
    try:
        response = requests.get(CLOUD_URL, params=CAR_B, timeout=3)
        data = response.json()

        if data.get("alerts"):
            for alert in data["alerts"]:
                hazard_id   = alert.get("id", "unknown")
                hazard_type = alert.get("hazard_type", "hazard").upper()
                distance    = alert.get("distance_m", "?")
                confidence  = alert.get("confidence", 0)
                lane        = alert.get("lane", "center")
                severity    = alert.get("severity", "high").upper()

                print("\n" + "!" * 55)
                print(f"  🚨 INCOMING ALERT — CAR B")
                print(f"  Hazard   : {hazard_type}")
                print(f"  Distance : {distance} metres ahead")
                print(f"  Lane     : {lane.upper()}")
                print(f"  Severity : {severity}")
                print(f"  Confidence: {round(confidence * 100)}%")
                print(f"  Action   : MOVE RIGHT — REDUCE SPEED")
                print("!" * 55 + "\n")

                # Speak the alert through speakers
                msg = (f"Warning! {hazard_type} ahead. "
                       f"{distance} metres. {lane} lane. "
                       f"Move right and reduce speed.")
                speak(msg)

                # Auto-verify if not already done
                if hazard_id not in alerted_ids:
                    try:
                        v = requests.post(
                            f"{VERIFY_URL}/{hazard_id}", timeout=2
                        )
                        vdata = v.json()
                        print(f"  ✅ Auto-verified hazard")
                        print(f"  New Confidence: "
                              f"{round(vdata.get('confidence', 0)*100)}%")
                        alerted_ids.add(hazard_id)
                    except:
                        pass
        else:
            print("🟢 Car B — Road clear. No hazards within 500m.")

    except requests.exceptions.ConnectionError:
        print("❌ Car B — Lost connection to backend")
    except Exception as e:
        print(f"❌ Car B — Error: {e}")

    time.sleep(3)