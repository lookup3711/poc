#!/bin/bash
set -euo pipefail

# ✅ 環境変数の設定
ENV="dev"
PROJECT="cmssoel"
REGION="ap-northeast-1"

ECR_REPO="343000763695.dkr.ecr.ap-northeast-1.amazonaws.com/${ENV}-${PROJECT}"
IMAGE_TAG="latest"
CONTAINER_PORT=8080
LOG_GROUP="/ecs/${ENV}-${PROJECT}"

# ✅ SecretsManager の ARN 取得
echo "🔍 シークレットの ARN を取得中..."
SECRET_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-secrets \
  --query "Stacks[0].Outputs[?OutputKey=='SecretArn'].OutputValue" \
  --output text \
  --region "$REGION")

# ✅ ネットワーク関連の Output 取得
echo "🔍 サブネットとセキュリティグループの情報を取得中..."
SUBNET_PRIVATE1=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-vpc \
  --query "Stacks[0].Outputs[?OutputKey=='SubnetPrivate1'].OutputValue" \
  --output text --region "$REGION")
SUBNET_PRIVATE2=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-vpc \
  --query "Stacks[0].Outputs[?OutputKey=='SubnetPrivate2'].OutputValue" \
  --output text --region "$REGION")

ECS_SG=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-sg \
  --query "Stacks[0].Outputs[?OutputKey=='EcsSecurityGroup'].OutputValue" \
  --output text --region "$REGION")

TG1_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-alb \
  --query "Stacks[0].Outputs[?OutputKey=='TargetGroup1Arn'].OutputValue" \
  --output text --region "$REGION")
TG2_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-alb \
  --query "Stacks[0].Outputs[?OutputKey=='TargetGroup2Arn'].OutputValue" \
  --output text --region "$REGION")
LISTENER_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-alb \
  --query "Stacks[0].Outputs[?OutputKey=='AlbListenerArn'].OutputValue" \
  --output text --region "$REGION")

# === ECSクラスタ・タスク定義・IAMロール ===
echo "▶️ 1. ECSクラスタ・タスク定義・IAMロールをデプロイ中..."
aws cloudformation deploy \
  --template-file cloudformation/compute/ecs.yaml \
  --stack-name ${ENV}-${PROJECT}-ecs \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    ECRRepositoryUri=$ECR_REPO \
    ECRImageTag=$IMAGE_TAG \
    ContainerPort=$CONTAINER_PORT \
    SecretArn=$SECRET_ARN \
    LogGroupName=$LOG_GROUP \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

# ✅ タスク定義とクラスタ名を取得
TASK_DEFINITION_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='TaskDefinitionArn'].OutputValue" \
  --output text --region "$REGION")
CLUSTER_NAME=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='ECSClusterName'].OutputValue" \
  --output text --region "$REGION")

# === ECS サービス（CodeDeploy Blue/Green 対応） ===
echo "▶️ 2. ECSサービスをデプロイ中..."
aws cloudformation deploy \
  --template-file cloudformation/compute/ecs-service.yaml \
  --stack-name ${ENV}-${PROJECT}-ecs-service \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    ECSClusterName=$CLUSTER_NAME \
    TaskDefinitionArn=$TASK_DEFINITION_ARN \
    AlbListenerArn=$LISTENER_ARN \
    TargetGroup1Arn=$TG1_ARN \
    TargetGroup2Arn=$TG2_ARN \
    SubnetPrivate1Id=$SUBNET_PRIVATE1 \
    SubnetPrivate2Id=$SUBNET_PRIVATE2 \
    EcsSecurityGroup=$ECS_SG \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

echo "✅ ECSサービスのデプロイが完了しました"
