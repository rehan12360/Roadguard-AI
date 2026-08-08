# 🚀 RoadGuard AI — Setup Guide

Deploy the **RoadGuard AI Edge-to-Cloud architecture** locally.

---

## 🏗️ Prerequisites
- **Flutter SDK** (v3.0.0+) with Android SDK tools configured.
- **Python** (v3.9+) for backend API.
- **Supabase Account** (for real-time database).

---

## 🛠️ Step 1: Database Setup (Supabase)
1. Create a new project on [Supabase](https://supabase.com).
2. Go to the SQL Editor and run:
   ```sql
   CREATE TABLE prototype_hazards (
       hazard_id TEXT PRIMARY KEY,
       vehicle_id TEXT,
       hazard_type TEXT,
       confidence NUMERIC,
       latitude NUMERIC,
       longitude NUMERIC,
       lane TEXT,
       severity TEXT,
       timestamp TEXT,
       status TEXT,
       verifications INTEGER,
       source TEXT,
       created_at TEXT
   );
   ```
3. **IMPORTANT**: Go to Authentication -> Policies, and **Disable RLS** for the `prototype_hazards` table (or add an INSERT policy).

---

## ☁️ Step 2: Cloud Backend Setup
1. Open terminal:
   ```bash
   cd cloud_backend
   pip install -r requirements.txt
   ```
2. Create a `.env` file based on `.env.example` and add your Supabase URL and Anon Key.
3. Start the FastAPI server (binds to your local IP so the phone can reach it):
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

---

## 📱 Step 3: Flutter Edge Client
1. Find your laptop's IPv4 address (e.g., `192.168.x.x`).
2. Update `api_service.dart` to point to your laptop's IP address.
3. Update `main.dart` with your Supabase URL and Anon Key.
4. Run the app on a physical device:
   ```bash
   cd flutter_app
   flutter pub get
   flutter run -d <your-device-id>
   ```
