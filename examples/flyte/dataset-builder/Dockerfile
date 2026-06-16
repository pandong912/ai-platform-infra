FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY dataset_builder ./dataset_builder
COPY specs ./specs

ENV PYTHONPATH=/app
