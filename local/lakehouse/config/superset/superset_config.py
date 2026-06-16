import os

SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "replace-with-a-local-random-secret")
SQLALCHEMY_DATABASE_URI = "sqlite:////app/superset_home/superset.db"

FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
}

WTF_CSRF_ENABLED = True
TALISMAN_ENABLED = False
