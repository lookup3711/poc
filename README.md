# poc
## ローカル動作確認
ビルド
docker build -t myapp-local ./app

ポートマッピング
docker run -p 8080:80 myapp-local

下記にアクセス
http://localhost:8080/

片付け
docker ps
docker stop <container id>
docker container prune
