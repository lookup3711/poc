#!/bin/bash
set -euo pipefail

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

# 設定
source ./env/${ENV}.env

# 出力取得
ALB_DNS_NAME=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-alb \
  --query "Stacks[0].Outputs[?OutputKey=='AlbArn'].OutputValue" \
  --output text \
  | xargs -I{} aws elbv2 describe-load-balancers \
      --load-balancer-arns {} \
      --query "LoadBalancers[0].DNSName" \
      --output text)

ALB_ZONE_ID=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-alb \
  --query "Stacks[0].Outputs[?OutputKey=='AlbArn'].OutputValue" \
  --output text \
  | xargs -I{} aws elbv2 describe-load-balancers \
      --load-balancer-arns {} \
      --query "LoadBalancers[0].CanonicalHostedZoneId" \
      --output text)

# Route 53 レコード作成
echo "✅ Creating A record for ${RECORD_NAME} → ${ALB_DNS_NAME}"

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Comment": "Alias for ALB",
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "'"${RECORD_NAME}"'",
          "Type": "A",
          "AliasTarget": {
            "HostedZoneId": "'"${ALB_ZONE_ID}"'",
            "DNSName": "'"${ALB_DNS_NAME}"'",
            "EvaluateTargetHealth": false
          }
        }
      }
    ]
  }'
