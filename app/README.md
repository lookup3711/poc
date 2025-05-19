# イメージビルドとPUSH
```
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin 343000763695.dkr.ecr.ap-northeast-1.amazonaws.com

cd ../app/
docker build -t dev-cmssoel .

docker tag dev-cmssoel:latest \
  343000763695.dkr.ecr.ap-northeast-1.amazonaws.com/dev-cmssoel:latest

docker push 343000763695.dkr.ecr.ap-northeast-1.amazonaws.com/dev-cmssoel:latest

クロスプラットフォームビルド＋PUSH
docker buildx build --platform linux/amd64 \
  -t 343000763695.dkr.ecr.ap-northeast-1.amazonaws.com/dev-cmssoel:latest \
  --push .

```