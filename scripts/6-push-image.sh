#!/bin/bash
set -euo pipefail

ENV="dev"
PROJECT="cmssoel"
REGION="ap-northeast-1"
TAG="latest"

REPO_URI=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-ecr \
  --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" \
  --output text --region "$REGION")

echo "🔐 ECR にログイン..."
aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin ${REPO_URI%%/*}

echo "🚀 Docker イメージをビルド中..."
docker buildx build --platform linux/amd64 \
  -t ${REPO_URI}:${TAG} \
  --push ./app

echo "✅ イメージのプッシュ完了"