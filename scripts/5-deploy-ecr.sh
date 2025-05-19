#!/bin/bash
set -euo pipefail

ENV="dev"
PROJECT="cmssoel"
REGION="ap-northeast-1"

echo "🚀 ECR リポジトリを作成中..."

aws cloudformation deploy \
  --template-file cloudformation/ecr/ecr.yml \
  --stack-name ${ENV}-${PROJECT}-ecr \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
  --region $REGION

echo "✅ ECR リポジトリ作成完了"
