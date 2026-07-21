# Slim official Python base keeps the image small.
FROM python:3.12-slim

# Don't buffer stdout/stderr (logs show up immediately) and don't write .pyc files.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Install dependencies first so this layer caches until requirements change.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code.
COPY app/ ./app/

# Run as a non-root user (good practice; also a security talking point).
RUN useradd --create-home appuser
USER appuser

EXPOSE 8000

# Container Apps / Azure will hit port 8000. 0.0.0.0 so it's reachable outside the container.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
