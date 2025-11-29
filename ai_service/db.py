import sqlite3
from typing import Optional, List, Dict, Any
import datetime

DB_PATH = 'ai_service.db'

def init_db(path: Optional[str] = None):
    p = path or DB_PATH
    conn = sqlite3.connect(p)
    cur = conn.cursor()
    cur.execute('''
    CREATE TABLE IF NOT EXISTS alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alert_type TEXT,
        description TEXT,
        timestamp TEXT,
        latitude REAL,
        longitude REAL
    )
    ''')
    conn.commit()
    conn.close()

def log_alert(alert_type: str, description: str, latitude: Optional[float] = None, longitude: Optional[float] = None, path: Optional[str] = None):
    p = path or DB_PATH
    conn = sqlite3.connect(p)
    cur = conn.cursor()
    ts = datetime.datetime.utcnow().isoformat()
    cur.execute('INSERT INTO alerts (alert_type, description, timestamp, latitude, longitude) VALUES (?, ?, ?, ?, ?)', (alert_type, description, ts, latitude, longitude))
    conn.commit()
    conn.close()

def get_hotspots(limit: int = 50, path: Optional[str] = None) -> List[Dict[str, Any]]:
    p = path or DB_PATH
    conn = sqlite3.connect(p)
    cur = conn.cursor()
    # Simple hotspot aggregation: group by rounded lat/lon
    cur.execute('''
    SELECT ROUND(latitude,3) as lat, ROUND(longitude,3) as lon, COUNT(*) as cnt
    FROM alerts
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL
    GROUP BY lat, lon
    ORDER BY cnt DESC
    LIMIT ?
    ''', (limit,))
    rows = cur.fetchall()
    conn.close()
    return [{'lat': r[0], 'lon': r[1], 'count': r[2]} for r in rows]


def get_recent_alerts(limit: int = 100, path: Optional[str] = None) -> List[Dict[str, Any]]:
    p = path or DB_PATH
    conn = sqlite3.connect(p)
    cur = conn.cursor()
    cur.execute('''
    SELECT id, alert_type, description, timestamp, latitude, longitude
    FROM alerts
    ORDER BY timestamp DESC
    LIMIT ?
    ''', (limit,))
    rows = cur.fetchall()
    conn.close()
    return [{'id': r[0], 'type': r[1], 'description': r[2], 'timestamp': r[3], 'latitude': r[4], 'longitude': r[5]} for r in rows]
