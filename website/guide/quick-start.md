# 快速开始

> ⚠️ **项目处于开发早期**：设计文档已定稿，代码正在按[路线图](/guide/roadmap)推进，以下命令为即将提供的形态预览。

## 环境要求

- JDK 21+
- Maven 3.8+

## 构建与运行

```bash
# 构建（产出可执行 fat JAR：oryxos-boot/target/oryxos.jar）
mvn clean package

# 初始化工作区（创建 .oryxos/ 目录，幂等）
oryxos init

# 创建一个 Agent（生成 .oryxos/agents/<name>/AGENT.md 最小模板）
oryxos profile create my-assistant

# 交互式对话
oryxos chat

# 或启动 REST API 服务（默认端口 8080，OpenAPI 文档在 /swagger-ui）
oryxos serve
```

## 两个可运行入口

OryxOS 交付物中有两个入口，职责不同：

| 入口 | 主类 | 用途 |
|------|------|------|
| **fat JAR** | `io.oryxlabs.oryxos.boot.OryxosApplication` | `java -jar oryxos.jar` 启动 Spring Boot + Web 容器，对外提供 REST API 与调度能力 |
| **CLI** | `io.oryxlabs.oryxos.cli.OryxOsCli` | Picocli 命令行入口，独立运行（如 `oryxos --version` 打印版本信息） |

## 一个目录 = 一个 Agent

定义一个每日天气 Agent，只需要在 `.oryxos/agents/daily-weather/AGENT.md` 里写：

```markdown
---
name: daily-weather
provider: { name: deepseek, model: deepseek-chat }
tools: [http_get, notify]
schedules: [{ cron: "0 0 8 * * *", message: "查一下今天天气并生成穿搭建议" }]
---

每天早上自动查天气、生成穿搭建议，通过 notify 推送到团队群（渠道名 team-lark）。
```

不写一行代码，到点自动运行，每次调用都有审计记录。

::: tip 安全提示
凭证（如 LLM API Key）不要明文写进 `AGENT.md` 的 frontmatter，用 `${ENV_VAR}` 形式从环境变量注入。
:::
