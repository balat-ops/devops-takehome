
# Stage 1: Install dependencies
FROM python:3.12-slim AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# Stage 2: Runtime image
FROM python:3.12-slim

WORKDIR /app

# Create a non-root application user
RUN groupadd --system appuser && \
    useradd --system --gid appuser --no-create-home appuser

# Copy installed dependencies
COPY --from=builder /install /usr/local

# Copy application code
COPY app/ ./app/

# Run as non-root user
USER appuser

EXPOSE 8080

# Start application using Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "4", "--worker-tmp-dir", "/tmp", "--access-logfile", "-", "app.main:app"]