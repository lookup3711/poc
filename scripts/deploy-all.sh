#!/bin/bash
set -euo pipefail

SCRIPTS=(
  "1-deploy-network.sh"
  "2-deploy-alb.sh"
  "3-create-route53-alias.sh"
  "4-deploy-secrets.sh"
  "5-deploy-ecr.sh"
  "6-push-image.sh"
  "7-deploy-ecs.sh"
  "8-deploy-codedeploy.sh"
)

echo "🚀 全スタックを順番にデプロイします"

for script in "${SCRIPTS[@]}"; do
  echo ""
  echo "==============================="
  echo "▶️ 実行中: scripts/$script"
  echo "==============================="
  bash "scripts/$script"
done

echo ""
echo "✅ すべてのデプロイが完了しました"
