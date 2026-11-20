# 通用业务管理平台部署模板

后端源码位于 [business-management-platform-be-template](business-management-platform-be-template/README.md)。派生平台预置 SQLite 和 MySQL 两套数据库及其全文、向量检索运行时。后端 Dockerfile 定义开发镜像，本目录 compose.yaml 定义数据库与验收服务。

## 部署目录验收

在本目录执行以下命令。首次构建需要 Docker、Compose、镜像仓库和 Python 包源。

```sh
docker compose --profile check config -q
docker compose run --build --rm --no-deps check
```

check 服务通过 BACKEND_DIR 找到源码并只读挂载到 /template。中文检索预期返回记录 1、2，向量检索预期返回记录 1、3。验收样本随容器清理。

## SQLite 持久化部署

1. 复制[部署样例](.env.example)为私有 .env。派生项目实现 HTTP 入口后，基于后端 Dockerfile 构建镜像，设置启动命令监听 0.0.0.0:8000，把本地镜像标签填入 BACKEND_IMAGE。
2. 运行 `docker compose --profile app up -d backend`。后端默认绑定宿主 127.0.0.1:8080，可用 BACKEND_BIND_PORT 调整。
3. backend-data 卷挂到 /var/lib/platform，容器内 DATA_DIR 固定为此路径。主库文件默认 platform.sqlite3，向量索引默认 vectors.sqlite3。后端账户需能写入该目录。备份、隔离恢复和事务入口见[SQLite 操作指南](business-management-platform-be-template/description/architecture/data/sqlite.md)。

按项目指定独立的 Compose 项目名（`docker compose -p 项目名 ...`），后续命令沿用该名以复用卷。停止服务使用 `docker compose --profile app down`，保留数据卷。

## MySQL 持久化部署

在部署目录私有 .env 中填写 MYSQL_PASSWORD 和 MYSQL_ROOT_PASSWORD 两个不同的随机口令。在空命名卷首次启动时，定制的 MySQL 8.4 镜像安装 MyVector，并创建空的应用数据库。执行：

```sh
docker compose --profile mysql up --build -d --wait mysql
docker compose run --build --rm mysql-client
```

应用通过内网 mysql:3306 连接，使用普通账号，数据和插件配置保存在 mysql-data 卷。派生服务使用 MySQL 时，先启动并等待 mysql 健康，再启动 backend。全部命令使用相同的 Compose 项目名。开发专用实例和生产实例分别管理凭据与卷。已有普通 MySQL 卷升级、操作 API 和 SQL 示例见 [MySQL 主库指南](business-management-platform-be-template/description/architecture/data/mysql.md)。隔离验收命令为 `./mysql/check.sh`。

## 钉钉应用的固定出口

在私有 .env 设置 DINGTALK_CORP_ID、DINGTALK_APP_KEY、DINGTALK_APP_SECRET、DINGTALK_PROXY_URL；单次请求超时默认 30 秒。应用和 visitor 共用网络空间时代理地址为 http://127.0.0.1:22888。部署样例在 dingtalk-egress/，搭建、Compose 覆盖文件与验收见[FRP 出口指南](business-management-platform-be-template/description/capability/infrastructure/dingtalk-frp-egress.md)。

## 连接已有中间件

在 deploy 的 `.env` 填写 `MIDDLEWARE_BASE_URL`、`MIDDLEWARE_PLATFORM_CODE`、`MIDDLEWARE_SECRET`，Compose 会把它们和超时、重试间隔传给 backend。填写后用 `docker compose --profile app up -d backend` 更新派生容器。地址应从 backend 容器可达，只填服务根地址。例如使用带有效证书的 HTTPS 域名；容器里的 127.0.0.1 指向该容器自身。中间件由其维护方部署。独立 SQLite/MySQL 和检索验收可保持三项为空。

后端模板提供专用测试平台的登录与心跳检查；部署前先从计划使用的网络验证可达性。后端检出后见 `description/api/middleware.md`，验收命令为 `python3 tests/check_middleware.py`。

## 将开发平台接到本机

业务人员提供映射机的 SSH Host 别名，派生项目的 Codex 按[本机开发映射](business-management-platform-be-template/description/capability/infrastructure/ssh-dev-mapping.md)发现现网配置，用 dev-mapping/connect.sh 建立网页入站和钉钉出站链路，验证候选上游后切换本平台开发路径。
