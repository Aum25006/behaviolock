import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()
db_url = os.getenv('DATABASE_URL')

try:
    print(f"Connecting to database...")
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()
    cur.execute("ALTER TABLE behavioral_profiles ADD COLUMN IF NOT EXISTS average_timings JSONB;")
    cur.execute("ALTER TABLE behavioral_profiles ADD COLUMN IF NOT EXISTS standard_deviations JSONB;")
    conn.commit()
    print("Migration successful! Added JSONB columns to behavioral_profiles.")
except Exception as e:
    print("Migration error:", e)
