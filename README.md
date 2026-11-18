# 通用业务管理平台部署模板

后端源码默认位于 [business-management-platform-be-template](business-management-platform-be-template/README.md)。在本目录运行以下命令，需要 Docker 和 Compose v2 或更新版本。当前可运行两项检索验收和持久化 MySQL。HTTP 服务须由派生项目提供可运行镜像。

## 部署配置文件

- [部署环境样例](.env.example)与 compose.yaml 同级。首次部署可运行 `cp -n .env.example .env`；macOS Finder 中按 `⌘ + Shift + .` 可显示隐藏文件。
- [MySQL 服务端配置](mysql/platform.cnf)由 Compose 只读挂载，统一设置字符集、排序规则、UTC 时区和中文全文检索的双字切分。库名、账户和密码在部署环境文件中填写。

## 先验收检索

```sh
docker compose --profile check config -q
docker compose run --rm --no-deps check
./tools/check-mysql.sh
docker compose run --rm --no-deps check sh -ec 'pip install -r /template/requirements/vector.txt && python -B /template/tools/check_search.py --vector'
```

第一项运行检查读取后端目录的脚本，只读挂载到 /template。MySQL 脚本使用独立容器、禁用外部网络、tmpfs 数据目录，完成后自动移除；镜像可通过 shell 环境 MYSQL_IMAGE 指定。向量命令需要容器可访问包源。三个检索命令均检查命中顺序，失败返回非零。预期 SQLite 和 MySQL 的全文检索均返回 1、2，向量返回 1、3。

## 持久化部署

1. 首次部署将 .env.example 复制为 .env（已有文件时逐项核对）。修改 MYSQL_PASSWORD 与 MYSQL_ROOT_PASSWORD 为不同的随机口令。MySQL 初始化变量只在空数据卷首次生效；已有数据库改密须同步更新数据库账户。
2. 运行 `docker compose --profile mysql up -d --wait mysql`，再运行 `docker compose ps` 确认 healthy。MySQL 位于 Compose 内网 mysql:3306，后端使用普通数据库账户。
3. 派生项目实现服务后，把已构建且本地可用的镜像标签写入 BACKEND_IMAGE。该镜像需自带启动命令、监听 0.0.0.0:8000、具有数据卷写权限，并实现后端配置契约。SQLite 模式只需 `docker compose --profile app up -d backend`。MySQL 模式先按第 2 步等待数据库就绪，将 DB_ENGINE 设为 mysql，再启动 backend。派生服务应能处理临时断连。
4. 后端对宿主默认绑定 127.0.0.1:8080，可通过 BACKEND_BIND_PORT 调整。按派生服务的接口文档验收；原始模板没有可供探活的 HTTP 入口。

| 变量或卷 | 路径与含义 |
| --- | --- |
| BACKEND_DIR | 相对 compose.yaml 的源码目录，供验收容器读取；移动后端后更新该值 |
| backend-data | 挂到 /var/lib/platform，容器内 DATA_DIR 固定为此路径；本地开发默认后端根目录的 data/ |
| SQLITE_FILENAME、VECTOR_INDEX_FILENAME | 分别为 DATA_DIR 下的主库与可选派生索引。派生服务应校验两个不同的单层文件名 |
| mysql-data | 挂到 /var/lib/mysql，持久化 MySQL 数据，与 backend-data 分开 |
| VECTOR_ENABLED | 默认 false；启用需派生镜像安装 requirements/vector.txt，并实现索引同步与权限复核 |

按项目分配独立的 Compose 项目名（`docker compose -p 项目名 ...`，使用小写 ASCII 标识），同一部署后续命令沿用该名以复用相同卷。停止服务用 `docker compose --profile '*' down`，保留命名卷。迁移时先做一致性备份，再在隔离实例恢复、核对业务记录和检索。单独复制活动 MySQL/SQLite 数据文件可能得到不一致的备份。
