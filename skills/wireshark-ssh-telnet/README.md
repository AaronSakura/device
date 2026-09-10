# Wireshark + SSH/Telnet 网络故障排查技能

一个可复用的网络排障 Skill:把"抓包分析"和"设备远程调试"串成闭环流程,适用于局域网设备巡检、故障定位与维护。

## 组成

```
SKILL.md                     流程主文档(5 步:依赖→假设→抓包→分析→设备核查)
scripts/net_capture.sh       抓包(自动选择 dumpcap/tshark/tcpdump)
scripts/pcap_summary.sh      抓包摘要(重传/RST/DNS/TLS/ARP 等故障指标)
scripts/device_probe.sh      SSH 执行命令 / Telnet 取 Banner / 端口探测
references/symptoms.md       症状对照表 + 结论模板 + 安全合规
```

## 依赖安装

```bash
sudo apt install wireshark tshark telnet      # Deepin / UOS / Debian
sudo usermod -aG wireshark $USER              # 允许普通用户抓包(需重新登录)
```

SSH/Telnet 调试设备前,确认已获得设备管理权限与网络授权。

## 快速开始

```bash
# 1. 抓包:抓 30 秒到某主机的 443 流量
bash scripts/net_capture.sh -i eth0 -f "host 10.0.0.8 and tcp port 443" -t 30 -o /tmp/cap.pcap

# 2. 分析:输出故障指标摘要
bash scripts/pcap_summary.sh /tmp/cap.pcap

# 3. 设备核查:SSH 登录设备看接口计数
bash scripts/device_probe.sh -H 192.168.1.1 -u admin -m ssh -c "show interface"

# 4. 老设备:Telnet(23 端口)取 Banner(仅实验环境)
bash scripts/device_probe.sh -H 192.168.1.1 -m telnet -p 23
```

## 安全说明

- Telnet 为明文协议,**仅限受控实验环境**;生产环境统一使用 SSH
- 抓包涉及流量数据,遵循最小必要原则,排查后及时清理证据文件

## 许可

MIT License(与所属仓库一致)
