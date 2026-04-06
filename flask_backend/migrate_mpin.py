import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()
db_url = os.getenv('DATABASE_URL')

try:
    print("Connecting to database for MPIN migration...")
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS mpin_hash VARCHAR(255);")
    conn.commit()
    print("Migration successful! Added mpin_hash to users.")
except Exception as e:
    print("Migration error:", e)
