#!/bin/sh
# 在独立临时实例验证中文 FULLTEXT，退出时仅清理本脚本创建的容器。
set -eu
container=$(docker run -d --network none --tmpfs /var/lib/mysql \
    -e MYSQL_ALLOW_EMPTY_PASSWORD=yes "${MYSQL_IMAGE:-mysql:8.4}")
trap 'docker rm -f "$container" >/dev/null' EXIT
trap 'exit 1' HUP INT TERM
client() {
    docker exec -i "$container" mysql --protocol=tcp -h127.0.0.1 -uroot \
        --default-character-set=utf8mb4 --batch --skip-column-names "$@"
}
attempt=0
until client -e 'SELECT 1' >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 90 ]; then
        echo 'MySQL 未能在 90 秒内就绪' >&2
        exit 1
    fi
    sleep 1
done
client <<'SQL'
SELECT VERSION(), @@ngram_token_size;
CREATE DATABASE fixture CHARACTER SET utf8mb4;
USE fixture;
CREATE TABLE docs (
    id INT PRIMARY KEY, body TEXT,
    FULLTEXT KEY ft_body (body) WITH PARSER ngram
) ENGINE=InnoDB;
INSERT INTO docs VALUES (1,'设备验收以及现场验收'), (2,'验收付款'), (3,'发票金额');
SQL
rows=$(client fixture <<'SQL'
SELECT id FROM docs
WHERE MATCH(body) AGAINST ('验收' IN NATURAL LANGUAGE MODE)
ORDER BY MATCH(body) AGAINST ('验收' IN NATURAL LANGUAGE MODE) DESC, id;
SQL
)
if [ "$rows" != "$(printf '1\n2')" ]; then
    echo "FULLTEXT 命中或排序异常 [$rows]" >&2
    exit 1
fi
echo 'MySQL FULLTEXT ngram 命中顺序 1, 2'
