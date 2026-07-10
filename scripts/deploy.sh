#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${CLUSTER:-}"
SERVICE="${SERVICE:-}"
REGION="${REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REPOSITORY_URI="${REPOSITORY_URI:-}"
ACCOUNT_ID="${ACCOUNT_ID:-}"

usage() {
  cat <<EOF
Usage: $0 --cluster <cluster> --service <service> --repository-uri <repo_uri> [--image-tag <tag>] [--region <region>] [--account-id <id>]

Options:
  --cluster         ECS cluster name
  --service         ECS service name
  --repository-uri  ECR repository URI without tag
  --image-tag       Image tag to push (default: latest)
  --region          AWS region (default: us-east-1)
  --account-id      AWS account ID, if not inferred from AWS CLI
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
    --repository-uri)
      REPOSITORY_URI="$2"
      shift 2
      ;;
    --image-tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --account-id)
      ACCOUNT_ID="$2"
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

if [[ -z "${CLUSTER}" || -z "${SERVICE}" || -z "${REPOSITORY_URI}" ]]; then
  echo "Missing required parameters."
  usage
  exit 1
fi

IMAGE_URI="${REPOSITORY_URI}:${IMAGE_TAG}"

echo "[deploy] Building Docker image ${IMAGE_URI}..."
docker build -t "${IMAGE_URI}" .

echo "[deploy] Logging in to ECR in ${REGION}..."
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${REPOSITORY_URI%/*}"

echo "[deploy] Pushing image ${IMAGE_URI}..."
docker push "${IMAGE_URI}"

echo "[deploy] Forcing ECS redeploy for ${CLUSTER}/${SERVICE}..."
aws ecs update-service --cluster "${CLUSTER}" --service "${SERVICE}" --force-new-deployment --region "${REGION}"

echo "[deploy] Deployed ${IMAGE_URI} to ${CLUSTER}/${SERVICE}."
