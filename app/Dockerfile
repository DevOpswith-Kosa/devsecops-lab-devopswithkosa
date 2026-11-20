# syntax=docker/dockerfile:1

# ---- build stage: install dependencies into /install -------------------
FROM python:3.14-slim AS build
WORKDIR /src
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- runtime stage: only what the app needs to run ---------------------
FROM python:3.14-slim
# Tell scanners and humans where the image came from.
LABEL org.opencontainers.image.title="kubenotes" \
      org.opencontainers.image.description="Notes API for the KubeAcademy DevSecOps track" \
      org.opencontainers.image.licenses="MIT"

# Patch OS packages the base image ships with known fixes for, then remove
# pip: the app never installs anything at runtime, and pip's vendored
# libraries are a large part of the image's CVE list.
# A fixed, unprivileged user. Kubernetes checks runAsNonRoot against this UID.
# hadolint ignore=DL3005
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && python -m pip uninstall -y pip \
 && groupadd --gid 10001 app \
 && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

COPY --from=build /install /usr/local
WORKDIR /app
COPY app.py .

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER 10001
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "app:app"]
