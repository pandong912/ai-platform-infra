FROM apache/superset:4.1.2

USER root

COPY requirements-local.txt /app/requirements-local.txt
RUN pip install --no-cache-dir -r /app/requirements-local.txt

USER superset
