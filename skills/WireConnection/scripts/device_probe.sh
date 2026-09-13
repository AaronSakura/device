#!/usr/bin/env bash
# device_probe.sh — 远程核查网络设备(SSH 执行命令 / Telnet 取 Banner / 端口探测)
# 用法:
#   device_probe.sh -H <主机> -m ssh    [-u 用户] [-p 22] [-c "show interface"] [-o 输出文件]
#   device_probe.sh -H <主机> -m telnet [-p 23] [-o 输出文件]
#   device_probe.sh -H <主机> -m port   [-p 443]
set -euo pipefail

HOST=""; USER_="admin"; PORT=""; MODE="ssh"; CMD=""; OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -H) HOST="$2"; shift 2 ;;
    -u) USER_="$2"; shift 2 ;;
    -p) PORT="$2"; shift 2 ;;
    -m) MODE="$2"; shift 2 ;;
    -c) CMD="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$HOST" ]] || { echo "必须指定 -H <主机>" >&2; exit 2; }
OUT="${OUT:-/tmp/device_${HOST}_$(date +%Y%m%d_%H%M%S).txt}"

{
  echo "### 设备核查 $(date '+%F %T') 主机=$HOST 模式=$MODE"
  echo

  echo "--- 连通性 ---"
  ping -c 3 -W 2 "$HOST" 2>&1 | tail -3

  case "$MODE" in
    ssh)
      PORT="${PORT:-22}"
      echo "--- 端口 $PORT 探测 ---"
      nc -z -w 3 "$HOST" "$PORT" && echo "端口 $PORT 可达" || echo "端口 $PORT 不可达"
      echo "--- SSH 执行: ${CMD:-uname -a} ---"
      ssh -o BatchMode=no -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
          -p "$PORT" "${USER_}@${HOST}" "${CMD:-uname -a}" 2>&1 || echo "(SSH 失败:检查用户名/密钥/设备是否开放 SSH)"
      ;;
    telnet)
      PORT="${PORT:-23}"
      echo "--- Telnet($PORT) Banner 抓取 ---"
      echo "[!] Telnet 为明文协议,仅限受控实验环境使用"
      if command -v telnet >/dev/null 2>&1; then
        timeout 6 bash -c "exec 3<>/dev/tcp/$HOST/$PORT && head -c 300 <&3" 2>&1 || echo "(无 Banner 或端口不可达)"
      else
        timeout 6 bash -c "exec 3<>/dev/tcp/$HOST/$PORT && head -c 300 <&3" 2>&1 || \
          echo "(无 Banner 或端口不可达;可安装 telnet 客户端: sudo apt install telnet)"
      fi
      ;;
    port)
      PORT="${PORT:-443}"
      echo "--- 端口 $PORT 探测 ---"
      nc -z -w 3 "$HOST" "$PORT" && echo "端口 $PORT 可达" || echo "端口 $PORT 不可达"
      ;;
    *) echo "未知模式: $MODE (支持 ssh/telnet/port)" >&2; exit 2 ;;
  esac

  echo
  echo "### 设备侧核对要点:接口错误计数(CRC/丢包)、CPU/内存、路由表、邻居表、最近日志"
} | tee "$OUT"

echo "[✓] 设备输出已保存: $OUT"
