# 部署模板维护

将 Compose、.env.example 和部署说明一起维护。每个 profile 写明启动条件、挂载路径、连接地址和验收命令。检索样例用临时数据，服务数据用独立持久卷。派生应用镜像在业务入口实现后接入。后端开发遵循子目录 AGENTS.md。修改变量后用 docker compose config 验证插值，检查输出时避免记录私有密码。

业务人员提供映射服务器的 SSH 别名后，按[本机开发映射](business-management-platform-be-template/description/capability/infrastructure/ssh-dev-mapping.md)接管本项目开发入口并连接其钉钉固定出口。部署专用入口在 dev-mapping/。
