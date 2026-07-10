#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-devel}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-}"

usage() {
  cat <<EOF
Usage: $0 [--environment <env>] [--container-image <image>]

Options:
  --environment   Terraform environment name (default: devel)
  --container-image  Optional ECR image URI to deploy
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --container-image)
      CONTAINER_IMAGE="$2"
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

echo "[tf-plan-apply] Environment: ${ENVIRONMENT}"
if [[ -n "${CONTAINER_IMAGE}" ]]; then
  echo "[tf-plan-apply] Using container image: ${CONTAINER_IMAGE}"
fi

pushd terraform >/dev/null

terraform init -upgrade
terraform validate

PLAN_ARGS=("-var=environment=${ENVIRONMENT}")
if [[ -n "${CONTAINER_IMAGE}" ]]; then
  PLAN_ARGS+=("-var=container_image=${CONTAINER_IMAGE}")
fi

terraform plan "${PLAN_ARGS[@]}" -out=tfplan
terraform apply -auto-approve tfplan

popd >/dev/null
