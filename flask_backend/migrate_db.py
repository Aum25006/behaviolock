from app import app
from extensions import db
from sqlalchemy import text

if __name__ == '__main__':
    with app.app_context():
        try:
            # We add average_timings and standard_deviations as JSONB. 
            db.session.execute(text("ALTER TABLE behavioral_profiles ADD COLUMN average_timings JSONB;"))
            db.session.execute(text("ALTER TABLE behavioral_profiles ADD COLUMN standard_deviations JSONB;"))
            db.session.commit()
            print("Successfully migrated behavioral_profiles table!")
        except Exception as e:
            print("Migration failed or already applied:", str(e))
