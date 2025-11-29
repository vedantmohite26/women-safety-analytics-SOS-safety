from flask import Flask, request, jsonify
import io
import datetime

# Try to import dependencies; prefer MediaPipe if available but support
# an OpenCV-only fallback so the service can run on lighter environments.
CV_AVAILABLE = True
try:
    import cv2
    import numpy as np
    from PIL import Image
    from db import init_db, log_alert, get_hotspots
    try:
        import mediapipe as mp
    except Exception:
        mp = None
except Exception:
    CV_AVAILABLE = False
    mp = None
    # provide no-op stubs for DB functions so server still starts
    def init_db(path=None):
        return None
    def log_alert(*args, **kwargs):
        return None
    def get_hotspots(*args, **kwargs):
        return []

app = Flask(__name__)

# Initialize DB
init_db()

# Prepare detectors: prefer MediaPipe if available; otherwise use OpenCV HOG person detector
if mp is not None:
    mp_pose = mp.solutions.pose
    mp_face = mp.solutions.face_detection
    pose_detector = mp_pose.Pose(static_image_mode=True, min_detection_confidence=0.4)
    face_detector = mp_face.FaceDetection(min_detection_confidence=0.4)
else:
    pose_detector = None
    face_detector = None
    # OpenCV HOG person detector
    if CV_AVAILABLE:
        hog = cv2.HOGDescriptor()
        hog.setSVMDetector(cv2.HOGDescriptor_getDefaultPeopleDetector())
    else:
        hog = None


def read_image_from_request(req) -> 'np.ndarray':
    # Accept image via multipart/form-data 'image' or raw body
    if 'image' in req.files:
        img_bytes = req.files['image'].read()
    else:
        img_bytes = req.get_data()
    img = Image.open(io.BytesIO(img_bytes)).convert('RGB')
    arr = np.array(img)
    return arr


def detect_people_and_poses(image: 'np.ndarray'):
    # image: HxWx3 RGB
    h, w, _ = image.shape
    persons = []
    # Prefer MediaPipe if available for pose/face
    if mp is not None and pose_detector is not None:
        results_pose = pose_detector.process(image)
        results_face = face_detector.process(image)
        if results_pose.pose_landmarks:
            lm = results_pose.pose_landmarks.landmark
            xs = [p.x for p in lm]
            ys = [p.y for p in lm]
            xmin = int(max(0, min(xs) * w))
            xmax = int(min(w - 1, max(xs) * w))
            ymin = int(max(0, min(ys) * h))
            ymax = int(min(h - 1, max(ys) * h))
            persons.append({'bbox': [xmin, ymin, xmax, ymax], 'pose_landmarks': [(p.x, p.y, p.z) for p in lm]})
        if results_face.detections:
            for det in results_face.detections:
                box = det.location_data.relative_bounding_box
                xmin = int(max(0, box.xmin * w))
                ymin = int(max(0, box.ymin * h))
                xmax = int(min(w - 1, (box.xmin + box.width) * w))
                ymax = int(min(h - 1, (box.ymin + box.height) * h))
                persons.append({'bbox': [xmin, ymin, xmax, ymax], 'face_score': float(det.score[0])})
    elif CV_AVAILABLE and 'hog' in globals() and hog is not None:
        # Convert RGB to BGR for OpenCV
        bgr = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
        rects, weights = hog.detectMultiScale(bgr, winStride=(8,8), padding=(8,8), scale=1.05)
        for i in range(len(rects)):
            x, y, wbox, hbox = rects[i]
            score = float(weights[i]) if i < len(weights) else 0.0
            xmin = int(x)
            ymin = int(y)
            xmax = int(x + wbox)
            ymax = int(y + hbox)
            persons.append({'bbox': [xmin, ymin, xmax, ymax], 'score': score})
    else:
        # No detector available; return empty list
        persons = []

    return persons


def detect_hands_up_from_pose(pose_landmarks):
    # Very simple heuristic: wrist y < nose y (normalized coords: smaller y is higher in image)
    # pose_landmarks: list of (x,y,z)
    try:
        # Landmark indices from MediaPipe
        # 0: nose, 15: left wrist, 16: right wrist
        nose = pose_landmarks[0]
        left_wrist = pose_landmarks[15]
        right_wrist = pose_landmarks[16]
        # y smaller means higher in image
        left_up = left_wrist[1] < nose[1]
        right_up = right_wrist[1] < nose[1]
        return left_up or right_up
    except Exception:
        return False


def detect_waving_from_pose(pose_landmarks, history=None):
    # Very rough heuristic: detect lateral oscillation of wrist x positions across recent frames.
    # For prototype we accept `history` as a list of wrist x positions; if not available, return False.
    try:
        if not history or len(history) < 3:
            return False
        # compute sign changes of delta x
        deltas = []
        for i in range(1, len(history)):
            deltas.append(history[i] - history[i-1])
        signs = [1 if d > 0 else (-1 if d < 0 else 0) for d in deltas]
        # count sign changes
        changes = sum(1 for i in range(1, len(signs)) if signs[i] != signs[i-1] and signs[i] != 0)
        return changes >= 2
    except Exception:
        return False


def detect_crossed_arms_from_pose(pose_landmarks):
    # Heuristic: left wrist is to the right of right shoulder and right wrist left of left shoulder (arms crossed)
    try:
        # indices: 11 left shoulder, 12 right shoulder, 15 left wrist, 16 right wrist
        l_sh = pose_landmarks[11]
        r_sh = pose_landmarks[12]
        l_wr = pose_landmarks[15]
        r_wr = pose_landmarks[16]
        # x coordinates
        # In normalized coords: x increases to the right
        crossed = (l_wr[0] > r_sh[0]) and (r_wr[0] < l_sh[0])
        return bool(crossed)
    except Exception:
        return False


@app.route('/analyze', methods=['POST'])
def analyze():
    """Analyze a single image frame.

    Request:
    - multipart/form-data 'image'
    - optional form fields: 'timestamp' (ISO), 'latitude', 'longitude', 'use_gender' (bool)

    Response JSON:
    - person_count, gender_distribution (placeholder), alerts[], persons[]
    """
    # If CV dependencies are missing, run in degraded 'mock' mode so the service can start
    if not CV_AVAILABLE:
        # allow callers to simulate persons with `mock_person_count` (form or query)
        try:
            mock_count = int(request.form.get('mock_person_count', request.args.get('mock_person_count') or 0))
        except Exception:
            mock_count = 0
        persons = []
        for i in range(mock_count):
            # simple placeholder bbox
            persons.append({'bbox': [10 + i * 50, 10, 60 + i * 50, 200], 'score': 0.9})

        person_count = len(persons)
        gender_dist = {'female': 0, 'male': 0, 'unknown': person_count}
        alerts = []

        # support manual alerting when client sends provided_gender and timestamp
        ts = request.form.get('timestamp') or request.args.get('timestamp')
        is_night = False
        if ts:
            try:
                t = datetime.datetime.fromisoformat(ts)
                hour = t.hour
                is_night = hour >= 20 or hour <= 5
            except Exception:
                is_night = False

        provided_gender = request.form.get('gender') or request.args.get('gender')
        if person_count == 1 and provided_gender and provided_gender.lower() == 'female' and is_night:
            alerts.append({'type': 'lone_woman_night', 'description': 'Single female detected at night (mock)'} )

        return jsonify({'person_count': person_count, 'gender_distribution': gender_dist, 'alerts': alerts, 'persons': persons})

    try:
        img = read_image_from_request(request)
    except Exception as e:
        return jsonify({'error': 'Could not read image', 'details': str(e)}), 400

    # Convert to RGB (already RGB)
    image_rgb = img.copy()

    persons = detect_people_and_poses(image_rgb)

    person_count = len(persons)

    # Simple gender placeholder: unknown for now
    gender_dist = {'female': 0, 'male': 0, 'unknown': person_count}

    alerts = []

    # Simple lone woman at night heuristic: if exactly 1 person, and caller told it's a woman and timestamp at night
    ts = request.form.get('timestamp') or request.args.get('timestamp')
    # parse hour if present
    is_night = False
    if ts:
        try:
            t = datetime.datetime.fromisoformat(ts)
            hour = t.hour
            is_night = hour >= 20 or hour <= 5
        except Exception:
            is_night = False

    # The prototype cannot reliably classify gender; accept an optional 'gender' param per-person for testing
    provided_gender = request.form.get('gender') or request.args.get('gender')

    if person_count == 1 and provided_gender and provided_gender.lower() == 'female' and is_night:
        alerts.append({'type': 'lone_woman_night', 'description': 'Single female detected at night'})
        # log to DB with optional coords
        lat = request.form.get('latitude')
        lon = request.form.get('longitude')
        try:
            lat_f = float(lat) if lat else None
            lon_f = float(lon) if lon else None
        except Exception:
            lat_f = lon_f = None
        log_alert('lone_woman_night', 'Single female detected at night', lat_f, lon_f)

    # Detect hands-up gestures per detected pose
    for p in persons:
        if 'pose_landmarks' in p:
            hands_up = detect_hands_up_from_pose(p['pose_landmarks'])
            if hands_up:
                alerts.append({'type': 'hands_up', 'description': 'Hands up detected (possible SOS)'} )
                lat = request.form.get('latitude')
                lon = request.form.get('longitude')
                try:
                    lat_f = float(lat) if lat else None
                    lon_f = float(lon) if lon else None
                except Exception:
                    lat_f = lon_f = None
                log_alert('hands_up', 'Hands up gesture detected', lat_f, lon_f)

    # Surround detection: if any person with provided gender female and >=2 other persons in proximity
    # Since we don't have reliable genders, support a testing parameter 'female_index' (0-based) to indicate which person is female.
    surround_flag = False
    female_index = request.form.get('female_index')
    if female_index is not None:
        try:
            fi = int(female_index)
            if fi < len(persons):
                fx1, fy1, fx2, fy2 = persons[fi]['bbox']
                fcx = (fx1 + fx2) / 2
                fcy = (fy1 + fy2) / 2
                nearby = 0
                for i, p in enumerate(persons):
                    if i == fi:
                        continue
                    x1, y1, x2, y2 = p['bbox']
                    pcx = (x1 + x2) / 2
                    pcy = (y1 + y2) / 2
                    # Euclidean distance in pixel space
                    dist = ((pcx - fcx) ** 2 + (pcy - fcy) ** 2) ** 0.5
                    if dist < 200:  # threshold pixels; tune per camera
                        nearby += 1
                if nearby >= 2:
                    surround_flag = True
                    alerts.append({'type': 'surrounded', 'description': f'Woman surrounded by {nearby} people'})
                    lat = request.form.get('latitude')
                    lon = request.form.get('longitude')
                    try:
                        lat_f = float(lat) if lat else None
                        lon_f = float(lon) if lon else None
                    except Exception:
                        lat_f = lon_f = None
                    log_alert('surrounded', f'Woman surrounded by {nearby} people', lat_f, lon_f)
        except Exception:
            pass

    return jsonify({'person_count': person_count, 'gender_distribution': gender_dist, 'alerts': alerts, 'persons': persons})


@app.route('/hotspots', methods=['GET'])
def hotspots():
    limit = int(request.args.get('limit', 50))
    hs = get_hotspots(limit=limit)
    return jsonify({'hotspots': hs})


@app.route('/alerts', methods=['GET'])
def alerts():
    # Lazy import to avoid failing when DB stubs are in place
    try:
        from db import get_recent_alerts
    except Exception:
        return jsonify({'alerts': []})
    limit = int(request.args.get('limit', 100))
    alerts = get_recent_alerts(limit=limit)
    return jsonify({'alerts': alerts})


@app.route('/alert', methods=['POST'])
def create_alert():
    """Create a manual alert. Accepts JSON with keys: alert_type, description, latitude, longitude, timestamp"""
    data = None
    try:
        data = request.get_json(force=True)
    except Exception:
        data = None
    if not data:
        return jsonify({'error': 'JSON required'}), 400
    alert_type = data.get('alert_type') or data.get('type') or 'manual'
    description = data.get('description') or data.get('desc') or 'manual alert'
    lat = data.get('latitude')
    lon = data.get('longitude')
    try:
        lat_f = float(lat) if lat is not None else None
        lon_f = float(lon) if lon is not None else None
    except Exception:
        lat_f = lon_f = None
    log_alert(alert_type, description, lat_f, lon_f)
    return jsonify({'status': 'ok', 'type': alert_type, 'description': description})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
