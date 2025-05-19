#!/bin/bash
set -euo pipefail

# ✅ 実行ディレクトリチェック（プロジェクトルート想定）
if [[ ! -f "scripts/8-deploy-codedeploy.sh" ]]; then
  echo "❌ このスクリプトはプロジェクトルートから実行してください。"
  exit 1
fi

# 📌 設定
ENV="dev"
PROJECT="cmssoel"
REGION="ap-northeast-1"
TEMPLATE_PATH="cloudformation/codedeploy/app.yml"
STACK_NAME="${ENV}-${PROJECT}-codedeploy"

# ✅ CloudFormation の Output を取得する関数
stack_output() {
  aws cloudformation describe-stacks \
    --stack-name "$1" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" \
    --output text \
    --region "$REGION"
}

echo "🔍 事前リソースの確認中..."

CLUSTER_NAME=$(stack_output "${ENV}-${PROJECT}-ecs" ECSClusterName)
SERVICE_NAME=$(stack_output "${ENV}-${PROJECT}-ecs-service" ECSServiceName)
TG1_ARN=$(stack_output "${ENV}-${PROJECT}-alb" TargetGroup1Arn)
TG2_ARN=$(stack_output "${ENV}-${PROJECT}-alb" TargetGroup2Arn)
LISTENER_ARN=$(stack_output "${ENV}-${PROJECT}-alb" AlbListenerArn)

echo "▶️ CodeDeploy スタックの作成中..."
aws cloudformation deploy \
  --template-file "$TEMPLATE_PATH" \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    ECSClusterName=$CLUSTER_NAME \
    ServiceName=$SERVICE_NAME \
    TargetGroup1Arn=$TG1_ARN \
    TargetGroup2Arn=$TG2_ARN \
    ListenerArn=$LISTENER_ARN \
  --capabilities CAPABILITY_NAMED_IAM

echo "✅ CodeDeploy スタックの作成が完了しました"
