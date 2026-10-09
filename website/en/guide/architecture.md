# Architecture

![OryxOS overall architecture](/images/docs-architecture-light.svg)

## Key Points

- **One entry for three triggers**: CLI / Web Service (human-pushed) and AgentScheduler (clock-pushed) converge on the same `AgentService`; the ReActLoop is agnostic to the message source
- **The engine orchestrates three capabilities**: each `ReActLoop` turn builds context via `PromptBuilder`, calls the LLM via `ProviderService`, and executes tools via `ToolExecutor` (after Sandbox whitelist checks), with audit persisted alongside each call
- **Storage sinks down**: sessions, audit and schedule state live in SQLite; Agent directories, bootstrap files and `MEMORY.md` live in the file system — directly editable and git-trackable
- **All external dependencies stay outside the boundary**: LLM APIs, external MCP servers and enterprise IM webhooks — OryxOS binds to none of them

## Tech Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | Java 21 | Native to enterprise Java ecosystems; virtual threads naturally fit long-blocking Agent calls |
| Framework | Spring Boot 3.x | Single executable fat JAR; reuses enterprise ops tooling |
| LLM access | Spring AI Alibaba | **Protocol adaptation + `@Tool` schema generation only**; the ReAct loop is self-implemented without its auto tool execution |
| Storage | SQLite (Spring Data JPA) | Zero-dependency embedded DB; explicit `SQLiteDialect` + `ddl-auto=none`, schema evolution via migration scripts |
| CLI | Picocli | Command-line entry, runs independently |
| Config | SnakeYAML | `AGENT.md` frontmatter parsing |

## Core-Phase Maven Modules (9)

| Module | Responsibility |
|--------|----------------|
| `oryxos-core` | ReActLoop, AgentService, PromptBuilder, Agent loading & scheduling |
| `oryxos-provider` | Provider abstraction and LLM protocol adaptation (reusing Spring AI Alibaba) |
| `oryxos-memory` | Session memory + long-term memory (`MEMORY.md`) |
| `oryxos-tool` | Built-in tools, Plugin Tool three-tier extension, ToolExecutor, Sandbox |
| `oryxos-channel-cli` | CLI interactive channel |
| `oryxos-web` | REST API / Web Service |
| `oryxos-storage` | SQLite persistence (sessions, audit, schedule state) |
| `oryxos-cli` | Picocli command-line entry (runs independently, prints version info, etc.) |
| `oryxos-boot` | Spring Boot main class and assembly, producing the fat JAR (`java -jar` entry) |

Modules currently have no inter-dependencies; `oryxos-boot` aggregates all 8 for assembly. Real dependencies are introduced story by story.

## Security & Audit

- **Whitelist sandbox**: every tool execution passes Sandbox validation first; file/shell/HTTP access outside the whitelist is rejected outright
- **No credential persistence**: sensitive config like LLM API keys is injected via `${ENV_VAR}` environment variables, never written in plaintext into `AGENT.md`
- **Full-chain audit**: `tool_invocations` / `llm_calls` audit tables are persisted from day one — every call is queryable
