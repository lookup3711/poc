# デプロイコマンド
```bash
cd cloudformation
aws cloudformation deploy \
  --template-file network/vpc.yaml \
  --stack-name dev-cmssoel-vpc \
  --parameter-overrides Environment=dev ProjectName=cmssoel \
  --capabilities CAPABILITY_NAMED_IAM

aws cloudformation deploy \
  --template-file network/igw_nat.yaml \
  --stack-name dev-cmssoel-igw-nat \
  --parameter-overrides \
      Environment=dev \
      ProjectName=cmssoel \
      VpcId=vpc-051d0a71d8f2baed8 \
      SubnetPublic1Id=subnet-096d1cca940a41008 \
  --capabilities CAPABILITY_NAMED_IAM

aws cloudformation deploy \
  --template-file network/route_tables.yaml \
  --stack-name dev-cmssoel-routes \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    VpcId=vpc-051d0a71d8f2baed8 \
    InternetGatewayId=igw-0fa0eb0f86def4d5f \
    NatGatewayId=nat-067260eb0eac385b4 \
    SubnetPublic1Id=subnet-096d1cca940a41008 \
    SubnetPublic2Id=subnet-06ddd091ab1c11492 \
    SubnetPrivate1Id=subnet-0639da9029153daac \
    SubnetPrivate2Id=subnet-0c813ec5a6e39064e

aws cloudformation deploy \
  --template-file network/sg.yaml \
  --stack-name dev-cmssoel-sg \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    VpcId=vpc-051d0a71d8f2baed8 \
    VpcCidrBlock=10.0.0.0/16

aws cloudformation deploy \
  --template-file network/vpc_endpoints.yaml \
  --stack-name dev-cmssoel-vpce \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    VpcId=vpc-051d0a71d8f2baed8 \
    SubnetPublic1Id=subnet-096d1cca940a41008 \
    SubnetPublic2Id=subnet-06ddd091ab1c11492 \
    PrivateRouteTableId=rtb-0d82f212beadd6419 \
    VpcEndpointSG=sg-0a55b471382184c9a

aws cloudformation deploy \
  --template-file network/alb.yaml \
  --stack-name dev-cmssoel-alb \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    VpcId=vpc-051d0a71d8f2baed8 \
    SubnetPublic1Id=subnet-096d1cca940a41008 \
    SubnetPublic2Id=subnet-06ddd091ab1c11492 \
    AlbSecurityGroup=sg-00115031d4d5cd412 \
    ACMCertificateArn=arn:aws:acm:ap-northeast-1:123456789012:certificate/abc-def-ghi-jkl \
    ListenerPort=443 \
    TargetPort=8080

aws cloudformation deploy \
  --template-file network/alb.yaml \
  --stack-name dev-cmssoel-alb \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    VpcId=vpc-051d0a71d8f2baed8 \
    SubnetPublic1Id=subnet-096d1cca940a41008 \
    SubnetPublic2Id=subnet-06ddd091ab1c11492 \
    AlbSecurityGroup=sg-00115031d4d5cd412 \
    TargetPort=8080 \
    ACMCertificateArn=""

ACMのARNは仮
TargetPortはECSの設定にあわせる

aws cloudformation deploy \
  --template-file secrets/secrets.yaml \
  --stack-name dev-cmssoel-secrets \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel

シークレットについては、スタックを削除しても消えないため注意
    DeletionPolicy: Retain のため
aws secretsmanager delete-secret \
  --secret-id cmssoel-dev \
  --force-delete-without-recovery

aws cloudformation deploy \
  --template-file ecr/ecr.yaml \
  --stack-name dev-cmssoel-ecr \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    AwsAccountId=343000763695  # アカウントID

aws cloudformation deploy \
  --template-file compute/ecs.yaml \
  --stack-name dev-cmssoel-ecs \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    ECRRepositoryUri=343000763695.dkr.ecr.ap-northeast-1.amazonaws.com/dev-cmssoel \
    ECRImageTag=latest \
    ContainerPort=8080 \
    SecretArn=arn:aws:secretsmanager:ap-northeast-1:343000763695:secret:cmssoel-dev-gekSfQ \
    LogGroupName=/ecs/dev-cmssoel \
    ECSTaskExecutionRoleArn=arn:aws:iam::343000763695:role/dev-cmssoel-ecs-task-execution-role \
  --capabilities CAPABILITY_NAMED_IAM

aws cloudformation deploy \
  --template-file compute/ecs-service.yaml \
  --stack-name dev-cmssoel-ecs-service \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    ECSClusterName=dev-cmssoel-cluster \
    TaskDefinitionArn=arn:aws:ecs:ap-northeast-1:343000763695:task-definition/dev-cmssoel-task:4 \
    AlbListenerArn=arn:aws:elasticloadbalancing:ap-northeast-1:343000763695:listener/app/dev-cmssoel-alb/715de56f7984f1bf/76133e2f1ca5e389 \
    TargetGroup1Arn=arn:aws:elasticloadbalancing:ap-northeast-1:343000763695:targetgroup/dev-cmssoel-tg1/decdaba7116f393f \
    TargetGroup2Arn=arn:aws:elasticloadbalancing:ap-northeast-1:343000763695:targetgroup/dev-cmssoel-tg2/bfeb6494e138c08b \
    SubnetPrivate1Id=subnet-0639da9029153daac \
    SubnetPrivate2Id=subnet-0c813ec5a6e39064e \
    EcsSecurityGroup=sg-0105eeb3a92f75149 \
  --capabilities CAPABILITY_NAMED_IAM

上記は途中でスタックしたので先にcodedeploy

aws cloudformation deploy \
  --template-file codedeploy/app.yaml \
  --stack-name dev-cmssoel-codedeploy \
  --parameter-overrides \
    Environment=dev \
    ProjectName=cmssoel \
    ServiceName=dev-cmssoel-service \
    ECSClusterName=dev-cmssoel-cluster \
    TargetGroup1Arn=arn:aws:elasticloadbalancing:ap-northeast-1:343000763695:targetgroup/dev-cmssoel-tg1/decdaba7116f393f \
    TargetGroup2Arn=arn:aws:elasticloadbalancing:ap-northeast-1:343000763695:targetgroup/dev-cmssoel-tg2/bfeb6494e138c08b \
    ListenerArn=arn:aws:elasticloadbalancing:ap-northeast-1:343000763695:listener/app/dev-cmssoel-alb/715de56f7984f1bf/76133e2f1ca5e389 \
  --capabilities CAPABILITY_NAMED_IAM

```

```bash
aws ecs register-task-definition \
  --cli-input-json file://deploy/taskdef.json


# create-deployment S3経由で実行（filebだとうまくいかなかった

yamashitaaogunoMacBook-Pro:poc lookup3711$ aws s3 mb s3://deploy-bucket --region ap-northeast-1
make_bucket: codeploy-bundles
yamashitaaogunoMacBook-Pro:poc lookup3711$ aws s3 cp deploy/bundle.zip s3://codeploy-bundles/dev-cmssoel/bundle.zip
upload: deploy/bundle.zip to s3://codeploy-bundles/dev-cmssoel/bundle.zip
yamashitaaogunoMacBook-Pro:poc lookup3711$ aws deploy create-deployment \
>   --application-name dev-cmssoel-cd-app \
>   --deployment-group-name dev-cmssoel-dg \
>   --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
>   --s3-location bucket=codeploy-bundles,key=dev-cmssoel/bundle.zip,bundleType=zip \
>   --region ap-northeast-1
{
    "deploymentId": "d-152LP4S60"
}
aws deploy create-deployment \
  --application-name dev-cmssoel-cd-app \
  --deployment-group-name dev-cmssoel-dg \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --s3-location bucket=codeploy-bundles,key=dev-cmssoel/bundle.zip,bundleType=zip \
  --region ap-northeast-1
```

## stack 削除
```bash
aws cloudformation delete-stack --stack-name dev-cmssoel-vpc
```

## クリーン手順

```bash
aws ecs update-service --cluster dev-cmssoel-cluster \
  --service dev-cmssoel-service \
  --desired-count 0 || true

aws ecs delete-service --cluster dev-cmssoel-cluster \
  --service dev-cmssoel-service \
  --force || true

aws ecs list-task-definitions \
  --family-prefix dev-cmssoel-task \
  --status INACTIVE \
  --query "taskDefinitionArns" --output text | \
  xargs -n1 aws ecs deregister-task-definition --task-definition

aws secretsmanager delete-secret \
  --secret-id cmssoel-dev \
  --force-delete-without-recovery

aws ecr delete-repository \
  --repository-name dev-cmssoel \
  --force

aws logs delete-log-group --log-group-name /ecs/dev-cmssoel || true

for stack in \
  dev-cmssoel-codedeploy \
  dev-cmssoel-ecs-service \
  dev-cmssoel-ecs \
  dev-cmssoel-secrets \
  dev-cmssoel-alb \
  dev-cmssoel-vpce \
  dev-cmssoel-sg \
  dev-cmssoel-routes \
  dev-cmssoel-igw-nat \
  dev-cmssoel-vpc
do
  echo "Deleting stack: $stack"
  aws cloudformation delete-stack --stack-name "$stack"
done


```