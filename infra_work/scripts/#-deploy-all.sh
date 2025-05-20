#!/bin/bash
set -euo pipefail

# ✅ 実行ディレクトリチェック
if [[ ! -f "scripts/#-deploy-all.sh" ]]; then
  echo "❌ Please run this script from the project root (e.g., ./scripts/#-deploy-all.sh)"
  exit 1
fi

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

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
  bash "scripts/$script" "${ENV}"
done

echo ""
echo "✅ すべてのデプロイが完了しました"
