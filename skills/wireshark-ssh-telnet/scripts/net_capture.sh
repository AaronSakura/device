#!/usr/bin/env bash
# net_capture.sh — 按接口/BPF 过滤器抓包,自动选择 dumpcap / tshark / tcpdump
# 用法: net_capture.sh -i <接口> -f "<BPF过滤>" [-t 时长秒] [-o 输出文件] [--snaplen N]
set -euo pipefail

IFACE=""
FILTER=""
DURATION=30
OUT="/tmp/capture_$(date +%Y%m%d_%H%M%S).pcap"
SNAPLEN=262144

usage() {
  echo "用法: $0 -i <接口> [-f \"BPF过滤\"] [-t 秒] [-o 输出文件] [--snaplen 字节]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i) IFACE="$2"; shift 2 ;;
    -f) FILTER="$2"; shift 2 ;;
    -t) DURATION="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    --snaplen) SNAPLEN="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "未知参数: $1" >&2; usage ;;
  esac
done

[[ -n "$IFACE" ]] || usage
ip link show "$IFACE" >/dev/null 2>&1 || { echo "接口不存在: $IFACE" >&2; exit 1; }

echo "[i] 接口=$IFACE 过滤器='${FILTER:-无}' 时长=${DURATION}s 输出=$OUT"

if command -v dumpcap >/dev/null 2>&1; then
  echo "[i] 使用 dumpcap 抓包"
  ARGS=(-i "$IFACE" -a "duration:$DURATION" -s "$SNAPLEN" -w "$OUT")
  [[ -n "$FILTER" ]] && ARGS+=(-f "$FILTER")
  dumpcap "${ARGS[@]}"
elif command -v tshark >/dev/null 2>&1; then
  echo "[i] 使用 tshark 抓包"
  ARGS=(-i "$IFACE" -a "duration:$DURATION" -s "$SNAPLEN" -w "$OUT")
  [[ -n "$FILTER" ]] && ARGS+=(-f "$FILTER")
  tshark "${ARGS[@]}" >/dev/null
elif command -v tcpdump >/dev/null 2>&1; then
  echo "[i] 使用 tcpdump 抓包"
  ARGS=(-i "$IFACE" -w "$OUT" -s "$SNAPLEN" -G "$DURATION" -W 1)
  [[ -n "$FILTER" ]] && ARGS+=("$FILTER")
  tcpdump "${ARGS[@]}" >/dev/null 2>&1
else
  echo "[x] 未找到 dumpcap/tshark/tcpdump,请先安装: sudo apt install tshark" >&2
  exit 1
fi

if [[ ! -s "$OUT" ]]; then
  echo "[x] 抓包结果为空:权限不足或接口无流量(尝试 sudo usermod -aG wireshark \$USER 后重新登录)" >&2
  exit 1
fi

COUNT=$(tshark -r "$OUT" 2>/dev/null | wc -l || echo 0)
echo "[✓] 抓包完成: $OUT (${COUNT} 包)"
echo "[i] 下一步: bash scripts/pcap_summary.sh $OUT"
