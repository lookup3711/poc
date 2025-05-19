#!/bin/bash
set -euo pipefail

SECRET_NAME="cmssoel-dev"
REGION="ap-northeast-1"

ARN=$(aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" \
  --query "ARN" \
  --output text)

echo "$ARN"
