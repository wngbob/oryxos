package io.oryxlabs.oryxos.boot;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * OryxOS Spring Boot 启动入口（oryxos-boot：启动模块 + 依赖聚合）。
 *
 * <p>骨架阶段：仅验证单体应用可启动、Web 容器可拉起、SQLite 数据源可装配；
 * 各能力模块尚未提供实现，随 user story 逐步挂接（见 CLAUDE.md 实施路线）。
 */
@SpringBootApplication
public class OryxosApplication {

    public static void main(String[] args) {
        SpringApplication.run(OryxosApplication.class, args);
    }
}
