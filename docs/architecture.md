# System Architecture

RoadGuard AI utilizes a hybrid Edge-to-Cloud architecture to minimize latency, reduce bandwidth costs, and provide real-time crowdsourced safety alerts.

## 1. The Edge Node (Flutter + OpenCV/YOLO)
Instead of streaming heavy 4K video feeds to a centralized cloud server (which induces high latency and bandwidth costs), we process the video locally on the edge node (the user's smartphone or dashcam).
- **Video Capture:** The Flutter app captures frames.
- **Inference:** A YOLOv8 model runs locally, detecting potholes, waterlogging, and road damage.
- **Lightweight Payload:** Only a tiny JSON payload (bounding boxes, GPS coordinates, confidence) is transmitted to the cloud.

## 2. Cloud Engine (FastAPI + Supabase)
The cloud acts as a highly scalable aggregation and geofencing hub.
- **Spatio-Temporal NMS:** When multiple cars report the same pothole, our Non-Maximum Suppression (NMS) algorithm mathematically merges the detections based on geospatial proximity (within 20 meters), increasing the **Crowd Consensus Score** rather than creating duplicates.
- **Database:** Supabase (PostgreSQL) handles real-time data persistence.

## 3. Spatial Geofencing Radar
We utilize the **Haversine Formula** to create dynamic 500-meter alert zones around newly detected hazards. Only vehicles entering this strict radius will receive the TTS (Text-to-Speech) audio warning, preventing alert fatigue for distant drivers.
