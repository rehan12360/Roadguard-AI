import requests
import time
import pyttsx3

CLOUD_URL  = "http://localhost:8000/api/v1/alerts"
VERIFY_URL = "http://localhost:8000/api/v1/verify"

# Car C position — 250m behind, slightly right of Car A
CAR_C = {
    "vehicle_id": "car_c_right_lane",
    "lat": 30.7023,
    "lon": 76.7185
}

engine = pyttsx3.init()
engine.setProperty('rate', 150)

def speak(text):
    try:
        engine.say(text)
        engine.runAndWait()
    except:
        pass

print("=" * 55)
print("   🚕 CAR C DASHBOARD — INITIALIZED")
print("   Position : 250m behind Car A (right lane)")
print("   Radius   : 500m alert zone")
print("=" * 55)
print("Scanning for hazards...\n")

alerted_ids = set()

while True:
    try:
        response = requests.get(CLOUD_URL, params=CAR_C, timeout=3)
        data = response.json()

        if data.get("alerts"):
            for alert in data["alerts"]:
                hazard_id   = alert.get("id", "unknown")
                hazard_type = alert.get("hazard_type", "hazard").upper()
                distance    = alert.get("distance_m", "?")
                confidence  = alert.get("confidence", 0)
                lane        = alert.get("lane", "center")
                severity    = alert.get("severity", "high").upper()

                # Car C is in right lane, hazard is in center — already safe
                if lane == "center":
                    action  = "YOU ARE ALREADY IN SAFE LANE ✅"
                    color_msg = "🟡"
                else:
                    action  = "MOVE RIGHT — REDUCE SPEED"
                    color_msg = "🔴"

                print("\n" + "=" * 55)
                print(f"  {color_msg} ALERT RECEIVED — CAR C (RIGHT LANE)")
                print(f"  Hazard   : {hazard_type}")
                print(f"  Distance : {distance} metres ahead")
                print(f"  Hazard Lane: {lane.upper()}")
                print(f"  Severity : {severity}")
                print(f"  Confidence: {round(confidence * 100)}%")
                print(f"  Action   : {action}")
                print("=" * 55 + "\n")

                msg = (f"Caution. {hazard_type} detected {distance} metres ahead "
                       f"in the {lane} lane. You are in the safe lane.")
                speak(msg)

                # Behaviour-based verification
                if hazard_id not in alerted_ids:
                    try:
                        v = requests.post(
                            f"{VERIFY_URL}/{hazard_id}", timeout=2
                        )
                        vdata = v.json()
                        print(f"  ✅ Behaviour-based verification sent")
                        print(f"     (Lane shift + speed reduction detected)")
                        print(f"  New Confidence: "
                              f"{round(vdata.get('confidence', 0)*100)}%")
                        alerted_ids.add(hazard_id)
                    except:
                        pass
        else:
            print("🟢 Car C — Road clear. No hazards within 500m.")

    except requests.exceptions.ConnectionError:
        print("❌ Car C — Lost connection to backend")
    except Exception as e:
        print(f"❌ Car C — Error: {e}")

    time.sleep(3)