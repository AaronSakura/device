---
name: wireshark-ssh-telnet-debug
description: "抓包分析与设备远程调试:用 Wireshark/tshark 定位丢包、延迟、DNS、端口不可达等网络故障,再用 SSH/Telnet 登录交换机、路由器等设备核查对端状态,形成证据闭环。"
metadata:
  {
    "openclaw":
      {
        "emoji": "📡",
        "requires": { "bins": ["tshark", "ssh"] },
      },
  }
---

# Wireshark + SSH/Telnet 网络故障排查

用于"网络异常 → 抓包分析 → 远程设备核查 → 定位根因"的完整排查流程。

## Step 0 — 确认依赖

```bash
command -v tshark dumpcap ssh
```

缺 tshark/dumpcap 时安装:`sudo apt install wireshark tshark`(Deepin/UOS/Debian)。
缺 telnet 客户端时:`sudo apt install telnet`;无法安装时脚本自动退回 `nc` 取 Banner。

**完成标准**:`tshark --version` 与 `ssh -V` 均有输出。

## Step 1 — 明确假设与抓包点

先写下一条可证伪的假设(例:"客户端到 10.0.0.8:443 丢包,疑似链路拥塞"),再确定:

- 抓包接口:`ip -br link` 查看,有线一般 `eth0`/`enp*`,无线 `wlan0`
- BPF 过滤器:`host 10.0.0.8 and tcp port 443`(不带过滤器会淹没在无关流量里)
- 抓包时长:先短抓 10–30 秒复现,避免长时间抓包占盘

**完成标准**:能用一句话写出"假设 + 接口 + 过滤器 + 时长"。

## Step 2 — 抓包

```bash
bash scripts/net_capture.sh -i eth0 -f "host 10.0.0.8 and tcp port 443" -t 30 -o /tmp/cap.pcap
```

脚本优先用 `dumpcap`(非 root 抓包权限更好),其次 `tshark -w`,最后 `tcpdump`。
若报权限错误,把用户加入 wireshark 组:`sudo usermod -aG wireshark $USER`,重新登录后生效。

**完成标准**:`tshark -r /tmp/cap.pcap -c 1` 能读出第一包,而不是"文件为空"。

## Step 3 — 分析与假设比对

```bash
bash scripts/pcap_summary.sh /tmp/cap.pcap
```

输出包含:协议分层、流量 Top 会话、TCP 重传/乱序、DNS 失败、TCP RST、TLS 告警。
按 `references/symptoms.md` 的症状对照表比对现象(重传高→链路/拥塞;大量 RST→对端拒绝或中间设备拦截;DNS NXDOMAIN→解析问题)。

**完成标准**:每个异常指标都能对应到表中一行,并写下"支持/否定假设"的判断。

## Step 4 — 远程设备核查(SSH / Telnet)

```bash
bash scripts/device_probe.sh -H 192.168.1.1 -u admin -m ssh        # 常规:SSH 执行命令
bash scripts/device_probe.sh -H 192.168.1.1 -p 23 -m telnet        # 老设备:23 端口取 Banner
```

在设备侧核查:接口错误计数(`show interface`)、CPU/内存、路由表、ARP/邻居表、日志(`show log`)。
Telnet 为明文协议,**仅限受控实验环境**;生产环境一律走 SSH,并在结论中注明该安全差异。

**完成标准**:拿到设备侧输出文件,且能指出与抓包现象对应的字段(如接口 CRC 错误、路由缺失)。

## Step 5 — 汇总结论与留证

把三样东西放在同一目录:`cap.pcap`、`summary.txt`、`device_output.txt`。
结论必须写成"现象 → 证据 → 根因 → 处置建议"四段式,证据指向具体包号或设备计数。

**完成标准**:他人仅凭这三份文件即可复核结论,无需重做实验。

## 验收

- 抓包文件可被 `tshark -r` 正常解析
- 摘要中每条异常均有对应假设判断
- 设备侧输出与抓包现象存在明确对应关系
- 结论含证据引用(包号/字段)与安全说明
