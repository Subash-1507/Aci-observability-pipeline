# syntax=docker/dockerfile:1
# Hardened API image: Chainguard Wolfi Python (rebuilt daily), base images pinned by digest.

# ---- build stage: installs hash-locked dependencies into /tmp/deps as the image's non-root user
FROM cgr.dev/chainguard/python:latest-dev@sha256:157a562dbc225a2a9039dbd8249cbf704202260ba27bf525f24e47a3a685050f AS build
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --require-hashes --only-binary=:all: --target /tmp/deps -r /tmp/requirements.txt

# ---- runtime stage: no shell, no package manager, non-root; code owned by root so the app cannot change it
FROM cgr.dev/chainguard/python:latest@sha256:35d6025b288eb1c40ae631db77ed6cdd26c6f51d898428d8fc9989db7f29e784
WORKDIR /app
COPY --from=build /tmp/deps ./deps
COPY src/ ./src/
ENV PYTHONPATH=/app/deps \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER 65532:65532
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]
# opentelemetry-instrument wraps uvicorn and switches on tracing, metrics and logs from OTEL_* variables
ENTRYPOINT ["python", "/app/deps/bin/opentelemetry-instrument", "python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
