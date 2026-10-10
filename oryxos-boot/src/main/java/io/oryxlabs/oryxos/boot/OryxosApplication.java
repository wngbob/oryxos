package io.oryxlabs.oryxos.boot;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * OryxOS Spring Boot 启动入口（oryxos-boot：启动模块 + 依赖聚合）。
 *
 * <p>骨架阶段：验证单体应用可启动、Web 容器可拉起、SQLite 数据源可装配，
 * 并已挂接审计表（{@code tool_invocations} / {@code llm_calls}）的实体与 Repository；
 * 其余能力模块尚未提供实现，随 user story 逐步挂接（见 CLAUDE.md 实施路线）。
 *
 * <p>实体与 Repository 都在兄弟包 {@code io.oryxlabs.oryxos.storage} 下，
 * 不在启动类的默认扫描路径内，因此显式声明扫描范围（否则 Spring Data 会报告
 * "Found 0 JPA repository interfaces"）。
 */
@SpringBootApplication
@EntityScan("io.oryxlabs.oryxos.storage.entity")
@EnableJpaRepositories("io.oryxlabs.oryxos.storage.repository")
public class OryxosApplication {

    public static void main(String[] args) {
        SpringApplication.run(OryxosApplication.class, args);
    }
}
