#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="rdicidr-local"
CONTAINER_NAME="rdicidr-local-check"
PORT=80

echo "[local-verify] Building Docker image ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" .

echo "[local-verify] Stopping and removing any existing container ${CONTAINER_NAME}..." || true
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

echo "[local-verify] Starting container ${CONTAINER_NAME}..."
docker run -d --name "${CONTAINER_NAME}" -p "${PORT}:80" "${IMAGE_NAME}"

cleanup() {
  echo "[local-verify] Cleaning up container ${CONTAINER_NAME}..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 3

echo "[local-verify] Verifying /healthz..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${PORT}/healthz)

if [[ "${HTTP_STATUS}" == "200" ]]; then
  echo "[local-verify] PASS: /healthz returned 200 OK"
  exit 0
fi

echo "[local-verify] FAIL: /healthz returned ${HTTP_STATUS}"
exit 1
