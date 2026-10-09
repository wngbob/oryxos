#!/usr/bin/env bash
#==============================================================
# OryxOS 打包脚本：编译 → 打包 → 上传远程
#
# 用法：
#   scripts/package.sh                 编译 + 打包 + 上传（需先设置 REMOTE_HOST）
#   scripts/package.sh --skip-build    跳过编译，直接打包上传
#   scripts/package.sh --skip-upload   只编译打包，不上传
#   scripts/package.sh --dry-run       打印将执行的上传命令，不真正上传
#   scripts/package.sh -h | --help     显示帮助
#
# 环境变量：
#   REMOTE_HOST      远程主机（上传必填），如 deploy@192.168.1.10
#   REMOTE_DIR       远程目标目录，默认 /opt/oryxos
#   JAVA_HOME        JDK 21 路径（未设置时自动回退到便携版工具链）
#   MVN              Maven 可执行文件（默认 mvn，PATH 找不到时回退便携版）
#   MAVEN_SETTINGS   Maven settings.xml（默认使用阿里云镜像配置，存在才生效）
#   SKIP_TESTS=1     编译阶段跳过测试
#
# 产物（dist/）：
#   oryxos.jar                     fat JAR（从 oryxos-boot/target/ 复制出来）
#   oryxos-src-<version>.tar.gz    源码包
#
# 说明：
#   源码包与上传均排除所有 target/ 构建产物，以及 node_modules、
#   .git、IDE 目录、.oryxos 工作区等本地文件；唯一上传的构建产物
#   是已脱离 target/ 目录的 dist/oryxos.jar。
#==============================================================
set -euo pipefail

# ---------- 路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
FAT_JAR="$ROOT_DIR/oryxos-boot/target/oryxos.jar"

# ---------- 可配置项 ----------
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_DIR="${REMOTE_DIR:-/opt/oryxos}"
SKIP_TESTS="${SKIP_TESTS:-0}"

SKIP_BUILD=0
SKIP_UPLOAD=0
DRY_RUN=0

usage() {
  sed -n '2,31p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { echo "错误：$*" >&2; exit 1; }

# ---------- 参数 ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)  SKIP_BUILD=1 ;;
    --skip-upload) SKIP_UPLOAD=1 ;;
    --dry-run)     DRY_RUN=1 ;;
    -h|--help)     usage 0 ;;
    *) usage 1 ;;
  esac
  shift
done

# ---------- 工具链（优先环境变量，回退便携版） ----------
if [[ -z "${JAVA_HOME:-}" && -d "/d/data/work/tools/jdk-21.0.12.1+1" ]]; then
  export JAVA_HOME="/d/data/work/tools/jdk-21.0.12.1+1"
fi

MVN_BIN="${MVN:-mvn}"
if ! command -v "$MVN_BIN" >/dev/null 2>&1; then
  if [[ -x "/d/data/work/tools/apache-maven-3.9.16/bin/mvn" ]]; then
    MVN_BIN="/d/data/work/tools/apache-maven-3.9.16/bin/mvn"
  else
    die "未找到 Maven，请设置 MVN 或将 mvn 加入 PATH"
  fi
fi

MVN_ARGS=(-B --no-transfer-progress)
if [[ -n "${MAVEN_SETTINGS:-}" && -f "$MAVEN_SETTINGS" ]]; then
  MVN_ARGS+=(-s "$MAVEN_SETTINGS")
elif [[ -f "/d/data/work/tools/maven-settings-aliyun.xml" ]]; then
  MVN_ARGS+=(-s "/d/data/work/tools/maven-settings-aliyun.xml")
fi

# ---------- 版本号（取根 pom 的 project.version） ----------
VERSION="$(grep -m1 '<version>' "$ROOT_DIR/pom.xml" | sed -E 's:.*<version>([^<]+)</version>.*:\1:' | tr -d '[:space:]')"
[[ -n "$VERSION" ]] || die "无法从 pom.xml 解析版本号"

TARBALL="$DIST_DIR/oryxos-src-$VERSION.tar.gz"

# ---------- [1/3] 编译 ----------
if [[ $SKIP_BUILD -eq 0 ]]; then
  log "[1/3] 编译：mvn clean package（version=$VERSION）"
  BUILD_ARGS=()
  if [[ "$SKIP_TESTS" == "1" ]]; then
    BUILD_ARGS+=(-DskipTests)
  fi
  "$MVN_BIN" "${MVN_ARGS[@]}" "${BUILD_ARGS[@]}" -f "$ROOT_DIR/pom.xml" clean package
else
  log "[1/3] 编译：跳过（--skip-build）"
fi

[[ -f "$FAT_JAR" ]] || die "未找到 fat JAR：$FAT_JAR（请先完成编译）"

# ---------- [2/3] 打包 ----------
log "[2/3] 打包：$DIST_DIR（源码包排除所有 target/ 产物）"
mkdir -p "$DIST_DIR"
cp -f "$FAT_JAR" "$DIST_DIR/oryxos.jar"

rm -f "$TARBALL"
tar czf "$TARBALL" \
  --exclude='target' \
  --exclude='dist' \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='.idea' \
  --exclude='.vscode' \
  --exclude='.oryxos' \
  --exclude='*.log' \
  --exclude='.DS_Store' \
  -C "$ROOT_DIR" .

# 双重校验：源码包里不允许出现任何 target/ 条目
if tar tzf "$TARBALL" | grep -qE '(^|/)target(/|$)'; then
  die "源码包中仍包含 target/ 产物，请检查 tar 排除规则"
fi

# ---------- [3/3] 上传 ----------
if [[ $SKIP_UPLOAD -eq 1 ]]; then
  log "[3/3] 上传：跳过（--skip-upload）"
elif [[ -z "$REMOTE_HOST" ]]; then
  log "[3/3] 上传：跳过（未设置 REMOTE_HOST）"
  echo "      示例：REMOTE_HOST=deploy@192.168.1.10 REMOTE_DIR=/opt/oryxos scripts/package.sh"
else
  command -v ssh >/dev/null 2>&1 || die "未找到 ssh 客户端"
  command -v scp >/dev/null 2>&1 || die "未找到 scp 客户端"

  if [[ $DRY_RUN -eq 1 ]]; then
    log "[3/3] 上传：dry-run"
    echo "[dry-run] ssh $REMOTE_HOST \"mkdir -p '$REMOTE_DIR'\""
    echo "[dry-run] scp $DIST_DIR/oryxos.jar $TARBALL $REMOTE_HOST:$REMOTE_DIR/"
  else
    log "[3/3] 上传：$REMOTE_HOST:$REMOTE_DIR/"
    ssh "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
    scp "$DIST_DIR/oryxos.jar" "$TARBALL" "$REMOTE_HOST:$REMOTE_DIR/"
  fi
fi

# ---------- 汇总 ----------
log "完成"
echo "版本：$VERSION"
ls -lh "$DIST_DIR/oryxos.jar" "$TARBALL" | awk '{print "  " $5 "  " $9}'
