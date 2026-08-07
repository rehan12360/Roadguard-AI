import requests
import time

CLOUD_URL = "http://localhost:8000/api/v1/alerts"

# Car D position — 800m away, OUTSIDE 500m radius
CAR_D = {
    "vehicle_id": "car_d_outside",
    "lat": 30.6974,
    "lon": 76.7179
}

print("=" * 55)
print("   🚌 CAR D DASHBOARD — INITIALIZED")
print("   Position : 800m from Car A (OUTSIDE radius)")
print("   Radius   : 500m alert zone")
print("   Expected : NO ALERTS (proves boundary works)")
print("=" * 55)
print("Monitoring...\n")

while True:
    try:
        response = requests.get(CLOUD_URL, params=CAR_D, timeout=3)
        data = response.json()

        if data.get("alerts"):
            # This should NEVER happen if radius logic is correct
            print("⚠️  UNEXPECTED: Car D received an alert!")
            print("    This means the 500m boundary is not working")
        else:
            print("✅ Car D — OUTSIDE RADIUS — No alerts received")
            print("   (800m away — 500m boundary is working correctly)")

    except requests.exceptions.ConnectionError:
        print("❌ Car D — Lost connection to backend")
    except Exception as e:
        print(f"❌ Car D — Error: {e}")

    time.sleep(3)