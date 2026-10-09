# Quick Start

> ⚠️ **Early stage**: the design is finalized and code is in progress per the [roadmap](/en/guide/roadmap). The commands below preview the upcoming form.

## Requirements

- JDK 21+
- Maven 3.8+

## Build & Run

```bash
# Build (produces the executable fat JAR: oryxos-boot/target/oryxos.jar)
mvn clean package

# Initialize the workspace (creates .oryxos/, idempotent)
oryxos init

# Create an Agent (generates a minimal .oryxos/agents/<name>/AGENT.md template)
oryxos profile create my-assistant

# Interactive chat
oryxos chat

# Or start the REST API service (default port 8080, OpenAPI docs at /swagger-ui)
oryxos serve
```

## Two Runnable Entries

OryxOS ships two entries with different responsibilities:

| Entry | Main class | Purpose |
|-------|-----------|---------|
| **fat JAR** | `io.oryxlabs.oryxos.boot.OryxosApplication` | `java -jar oryxos.jar` starts Spring Boot + web container, exposing REST API and scheduling |
| **CLI** | `io.oryxlabs.oryxos.cli.OryxOsCli` | Picocli command-line entry, runs independently (e.g. `oryxos --version` prints version info) |

## One Directory = One Agent

To define a daily-weather Agent, just write `.oryxos/agents/daily-weather/AGENT.md`:

```markdown
---
name: daily-weather
provider: { name: deepseek, model: deepseek-chat }
tools: [http_get, notify]
schedules: [{ cron: "0 0 8 * * *", message: "Check today's weather and give outfit advice" }]
---

Every morning, check the weather, generate outfit advice, and push it to the
team group via notify (channel name team-lark).
```

No code. Runs on schedule. Every call audited.

::: tip Security note
Never write credentials (e.g. LLM API keys) in plaintext into `AGENT.md` frontmatter — inject them from environment variables via `${ENV_VAR}` placeholders.
:::
