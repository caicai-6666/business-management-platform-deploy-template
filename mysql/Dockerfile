FROM ghcr.io/askdba/myvector:mysql8.4@sha256:219c74a5735c3150391cd4b818d148baddabf229ce6cb0eaa05f5f2070d3ae7f AS myvector

FROM mysql:8.4
COPY --from=myvector /usr/lib/mysql/plugin/myvector.so /usr/lib/mysql/plugin/myvector.so
RUN if [ -d /usr/lib64/mysql/plugin ]; then cp /usr/lib/mysql/plugin/myvector.so /usr/lib64/mysql/plugin/; fi
COPY --from=myvector /docker-entrypoint-initdb.d/myvectorplugin.sql /docker-entrypoint-initdb.d/010-myvector-plugin.sql
COPY platform.cnf /etc/mysql/conf.d/platform.cnf
COPY init/ /docker-entrypoint-initdb.d/
CMD ["mysqld", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_0900_ai_ci"]
