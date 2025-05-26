#!/bin/bash
set -euo pipefail

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

# === 設定 ===
source ./env/${ENV}.env

echo "🚀 ECR リポジトリを作成中..."

aws cloudformation deploy \
  --template-file cloudformation/ecr/ecr.yml \
  --stack-name ${ENV}-${PROJECT}-ecr \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    ECRName="$ECR_REPO_NAME" \
  --region $REGION

echo "✅ ECR リポジトリ作成完了"
