#!/usr/bin/env bash
# run_demo.sh — 答辩演示:生成流量 → 抓包 → 分析 → 设备核查,一条龙产出证据
# 用法: bash run_demo.sh [输出目录]
set -uo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${1:-/tmp/net_demo_$(date +%H%M%S)}"
mkdir -p "$OUTDIR"
STEP=0
step() { STEP=$((STEP+1)); echo; echo "======== 步骤 $STEP: $* ========"; }

step "依赖检查"
for b in tshark ssh nc; do
  printf '  %-8s ' "$b"
  if command -v "$b" >/dev/null 2>&1; then echo "OK"; else echo "缺失(安装: sudo apt install wireshark tshark telnet)"; fi
done

step "生成测试流量(本地 HTTP 服务 + 正常请求 + 失败请求)"
python3 -m http.server 18080 --bind 127.0.0.1 >/dev/null 2>&1 &
SRV=$!
sleep 1
for i in 1 2 3 4 5; do curl -s -o /dev/null --max-time 2 http://127.0.0.1:18080/ ; done
curl -s -o /dev/null --max-time 2 http://127.0.0.1:18081/           # 连接被拒绝
curl -s -o /dev/null --max-time 3 http://no-such-host.invalid/ 2>/dev/null || true  # 域名解析失败
echo "  [i] 已产生:5 次正常 HTTP 请求 + 1 次端口拒绝 + 1 次 DNS 失败"

step "抓包(lo 接口,8 秒)"
if command -v tshark >/dev/null 2>&1 || command -v dumpcap >/dev/null 2>&1 || command -v tcpdump >/dev/null 2>&1; then
  bash "$BASE/scripts/net_capture.sh" -i lo -t 8 -o "$OUTDIR/cap.pcap"
else
  echo "  [!] 未安装抓包工具,本步骤跳过"
  echo "  [!] 演示前请先执行: sudo apt install wireshark tshark"
fi

step "设备核查(本地 18080 可达 / 22 不可达)"
bash "$BASE/scripts/device_probe.sh" -H 127.0.0.1 -m port -p 18080 -o "$OUTDIR/device_18080.txt"
bash "$BASE/scripts/device_probe.sh" -H 127.0.0.1 -m port -p 22    -o "$OUTDIR/device_22.txt"

kill "$SRV" 2>/dev/null || true

step "抓包分析"
if [ -s "$OUTDIR/cap.pcap" ]; then
  bash "$BASE/scripts/pcap_summary.sh" "$OUTDIR/cap.pcap" "$OUTDIR/summary.txt"
else
  echo "  [!] 无 pcap 文件,本步骤跳过"
fi

step "汇总"
ls -la "$OUTDIR"
echo
echo "[✓] 演示完成。证据目录: $OUTDIR"
echo "    结论写法参考 references/symptoms.md 的『处置建议模板』"
