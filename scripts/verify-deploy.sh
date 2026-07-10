#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${CLUSTER:-}"
SERVICE="${SERVICE:-}"
REGION="${REGION:-us-east-1}"
ALB_DNS="${ALB_DNS:-}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-15}"

usage() {
  cat <<EOF
Usage: $0 --cluster <cluster> --service <service> --alb-dns <alb_dns> [--region <region>] [--timeout <seconds>] [--interval <seconds>]

Options:
  --cluster     ECS cluster name
  --service     ECS service name
  --alb-dns     ALB DNS name to verify
  --region      AWS region (default: us-east-1)
  --timeout     Seconds to wait for runningCount to match desiredCount (default: 300)
  --interval    Poll interval in seconds (default: 15)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      CLUSTER="$2"
      shift 2
      ;;
    --service)
      SERVICE="$2"
      shift 2
      ;;
    --alb-dns)
      ALB_DNS="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --interval)
      INTERVAL_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown flag: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${CLUSTER}" || -z "${SERVICE}" || -z "${ALB_DNS}" ]]; then
  echo "Missing required parameters."
  usage
  exit 1
fi

echo "[verify-deploy] Polling ECS service ${CLUSTER}/${SERVICE} until runningCount == desiredCount..."
END_TIME=$((SECONDS + TIMEOUT_SECONDS))

while [[ SECONDS -lt END_TIME ]]; do
  SERVICE_DESC=$(aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE}" --region "${REGION}" --output json)
  RUNNING_COUNT=$(echo "${SERVICE_DESC}" | jq -r '.services[0].runningCount')
  DESIRED_COUNT=$(echo "${SERVICE_DESC}" | jq -r '.services[0].desiredCount')

  echo "[verify-deploy] runningCount=${RUNNING_COUNT}, desiredCount=${DESIRED_COUNT}"

  if [[ "${RUNNING_COUNT}" == "${DESIRED_COUNT}" ]]; then
    echo "[verify-deploy] ECS service reached desired count."
    break
  fi

  sleep "${INTERVAL_SECONDS}"
done

if [[ "${RUNNING_COUNT}" != "${DESIRED_COUNT}" ]]; then
  echo "[verify-deploy] FAIL: ECS service did not reach desired count within timeout."
  exit 1
fi

echo "[verify-deploy] Checking ALB endpoints..."
for PATH in "/" "/healthz"; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}${PATH}")
  echo "[verify-deploy] GET ${PATH} -> ${HTTP_STATUS}"
  if [[ "${HTTP_STATUS}" != "200" ]]; then
    echo "[verify-deploy] FAIL: ${PATH} did not return 200"
    exit 1
  fi
done

echo "[verify-deploy] PASS: ALB endpoints are healthy."
