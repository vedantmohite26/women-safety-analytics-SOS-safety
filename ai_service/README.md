# Women Safety Analytics — AI Service Prototype

This folder contains a small prototype AI service for Women Safety Analytics.

What this prototype does
- Accepts image frames via POST `/analyze` and returns detected persons, simple pose-based gesture detection (hands-up), and emits alerts for simple heuristics.
- Stores alerts in a small SQLite DB and exposes `/hotspots` to return aggregated hotspots.

Limitations
- This is a lightweight prototype using MediaPipe for person/pose/face detection. It does NOT include robust gender classification or state-of-the-art object detectors (YOLOv5/YOLOv8) — those can be added later.
- Gender classification is left as a placeholder due to privacy and accuracy considerations. The API supports optional test parameters to mark a person as female for testing heuristics.

Quick start
1. Create a Python virtualenv and install deps:
```cmd
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```
2. Run the service:
```cmd
python app.py
```
3. Example request (using `curl`):
```cmd
curl -X POST -F "image=@frame.jpg" -F "timestamp=2025-11-24T22:30:00" -F "gender=female" http://localhost:5000/analyze
```

API
- `POST /analyze` — multipart form: `image` file. Optional fields: `timestamp`, `latitude`, `longitude`, `gender`, `female_index` (index into detected persons for surround testing).
- `GET /hotspots` — returns aggregated hotspots from logged alerts.

- `GET /alerts` — returns recent alerts (id, type, description, timestamp, latitude, longitude).

Integration notes for Flutter app (camera -> server)

1) Capture frames periodically (e.g., 1 FPS or when movement detected) using `camera` plugin in Flutter.
2) Encode frame as JPEG and POST to `/analyze` as multipart form field `image`.
3) Include optional `timestamp`, `latitude`, `longitude` fields to allow location and time-based heuristics.
4) Parse JSON response: if `alerts` array is non-empty, show immediate UI notification and optionally send push notification.

Sample Flutter snippet (Dart) to POST a JPEG frame:

```dart
import 'package:http/http.dart' as http;

Future<void> uploadFrame(Uint8List jpegBytes) async {
	var uri = Uri.parse('http://YOUR_SERVER:5000/analyze');
	var req = http.MultipartRequest('POST', uri);
	req.files.add(http.MultipartFile.fromBytes('image', jpegBytes, filename: 'frame.jpg'));
	req.fields['timestamp'] = DateTime.now().toIso8601String();
	// Optionally add lat/lon
	// req.fields['latitude'] = '12.34';
	// req.fields['longitude'] = '56.78';
	var res = await req.send();
	final body = await res.stream.bytesToString();
	print(body);
}
```

UI suggestions
- Mobile app: show a live camera preview, a small overlay with current `male/female` counts and alert badge. Allow a one-tap panic button that triggers an immediate alert to the server.
- Web dashboard: show list of recent alerts, live feeds, and a heatmap built from `/hotspots` data (round lat/lon to 3 decimals for coarse buckets).

Ethical & privacy notes
- Gender classification has accuracy and bias concerns; ensure you have consent and follow local laws and data minimization practices. When possible, prefer operator-assisted reviews or only use gender-agnostic threat signals.
- Secure the API (HTTPS, authentication), and avoid storing raw images unless absolutely necessary. Use hashed IDs and short retention periods for PII.

Next steps
- Integrate a proper person detector (YOLO) and a carefully validated gender classifier (if ethically approved).
- Add streaming support (WebRTC), faster frame processing, GPU acceleration, and authenticated APIs.
