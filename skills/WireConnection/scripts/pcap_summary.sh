#!/usr/bin/env bash
# pcap_summary.sh — 输出 pcap 的关键故障指标摘要(协议分层/会话/重传/DNS/RST/TLS)
# 用法: pcap_summary.sh <文件.pcap> [输出文件]
set -euo pipefail

PCAP="${1:-}"
OUT="${2:-/tmp/summary_$(date +%Y%m%d_%H%M%S).txt}"

[[ -n "$PCAP" ]] || { echo "用法: $0 <文件.pcap> [输出文件]" >&2; exit 2; }
[[ -s "$PCAP" ]] || { echo "文件不存在或为空: $PCAP" >&2; exit 1; }
command -v tshark >/dev/null 2>&1 || { echo "需要 tshark: sudo apt install tshark" >&2; exit 1; }

run() { echo "===== $1 ====="; shift; "$@" || echo "(无结果)"; echo; }

{
  echo "### 抓包摘要 $(date '+%F %T') 文件=$PCAP"
  echo

  run "协议分层统计" tshark -r "$PCAP" -q -z io,phs
  run "流量最多的会话(Top 10)" tshark -r "$PCAP" -q -z conv,tcp
  run "TCP 重传(前 20 条)" bash -c "tshark -r '$PCAP' -Y 'tcp.analysis.retransmission' -T fields -e frame.number -e ip.src -e ip.dst -e tcp.seq 2>/dev/null | head -20"
  run "TCP 重置(RST,前 20 条)" bash -c "tshark -r '$PCAP' -Y 'tcp.flags.reset==1' -T fields -e frame.number -e ip.src -e ip.dst -e tcp.port 2>/dev/null | head -20"
  run "DNS 失败响应(NXDOMAIN/无响应)" bash -c "tshark -r '$PCAP' -Y 'dns.flags.rcode!=0' -T fields -e frame.number -e dns.qry.name -e dns.flags.rcode 2>/dev/null | head -20"
  run "TCP 三次握手失败(SYN 无 ACK 回包)" bash -c "tshark -r '$PCAP' -Y 'tcp.flags.syn==1 and tcp.flags.ack==0' -T fields -e frame.number -e ip.src -e ip.dst -e tcp.dstport 2>/dev/null | head -20"
  run "TLS 告警/握手异常" bash -c "tshark -r '$PCAP' -Y 'tls.alert_message' -T fields -e frame.number -e ip.src -e ip.dst -e tls.alert_message.desc 2>/dev/null | head -20"
  run "ARP 请求统计(判断广播风暴)" bash -c "tshark -r '$PCAP' -Y 'arp.opcode==1' 2>/dev/null | wc -l"
  run "ICMP 不可达" bash -c "tshark -r '$PCAP' -Y 'icmp.type==3' -T fields -e frame.number -e ip.src -e ip.dst 2>/dev/null | head -10"

  echo "### 对照 references/symptoms.md 逐条判断:支持/否定最初假设"
} | tee "$OUT"

echo "[✓] 摘要已保存: $OUT"
