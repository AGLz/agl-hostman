# Varredura de rede a partir de agldv06 (CT108)

**Data (UTC):** 2026-04-04T15:08:55Z  
**Origem:** `agldv06` — Debian 12 (bookworm), kernel `6.8.12-15-pve`  
**Tailscale:** `100.71.229.12` (`aglsrv6-agldv06.degu-chromatic.ts.net`)

### Atualização pós-migração (2026-04-04)

- **Pi-hole (`pihole6`)**: VMID **117** (antes **115**), LAN **`192.168.0.117/24`**, MAC veth Proxmox **`bc:24:11:01:70:73`**. CT115 removido (`pct destroy --purge`).
- **Motivo**: libertar **`192.168.0.115`** para o equipamento **TP-LINK** com IP fixo (deixou de haver conflito ARP com o Pi-hole).
- Os dados abaixo na secção “Varredura” e no anexo reflectem o **estado na hora da recolha**; a tabela Excel foi **ajustada** para o inventário lógico actual (ver nota no ficheiro `.xlsx`).

## Ferramentas

| Ferramenta | Versão / notas |
|------------|----------------|
| `nmap` | 7.93+dfsg1-1 — ping sweep (`-sn`) em /24 |
| `arp-scan` | 1.10.0-2 — descoberta L2 por interface |
| `fping` | 5.1-1 — confirmação ICMP (amostra parcial vs ARP) |

**Nota:** `apt-get update` no CT reporta avisos GPG em repos de terceiros (sury PHP, Yarn, etc.); pacotes Debian principais instalaram na mesma.

## Interfaces e encaminhamento

| Interface | IPv4 | Observação |
|-----------|------|------------|
| `eth0` | 192.168.0.108/24 | Gateway default `192.168.0.1` |
| `eth1` | 192.168.60.108/24 | Segmento interno / storage |
| `tailscale0` | 100.71.229.12/32 | Overlay Tailscale |

## Vizinhos ARP (kernel) — eth0

Vistos no momento da recolha: gateway `.1`, `.102`, `.212`, `.115` (na altura ainda associado ao Pi-hole em `.115`); entrada `.179` em estado FAILED. **Após migração:** Pi-hole em **`.117`**; **`.115`** reservado ao TP-LINK.

## Tailscale (vista a partir deste nó)

- Lista completa de peers do tailnet no output da execução (49 nós visíveis no ambiente de teste).
- **Avisos de saúde reportados pelo cliente:**
  - DNS configurados no Tailscale possivelmente inacessíveis (conectividade Internet/DNS).
  - Alguns peers anunciam rotas mas `--accept-routes` está desativado neste nó.

## LAN 192.168.0.0/24 (eth0)

### Resumo

| Método | Hosts “up” / respostas |
|--------|-------------------------|
| `arp-scan` | **42** respostas ARP |
| `nmap -sn` | **45** hosts up |
| `fping` | **27** (ICMP pode falhar por firewall; subconjunto esperado) |

### Padrões observados

- Muitos prefixos **`bc:24:11:*`** — típico de **MACs atribuídos por virtualização (Proxmox/KVM)**; alinha com CTs/VMs na LAN.
- Bloco **192.168.0.180–195, 234** com **Dell Inc.** — provável cluster de servidores Dell.
- **192.168.0.183** com MAC Dell — alinha com **Archon** na documentação AGL (LAN 192.168.0.183).
- **192.168.0.212** — **TP-LINK** (p.ex. AP/switch gerido).
- **192.168.0.115** (recolha) — duas entradas ARP (MAC Proxmox do Pi-hole antigo + TP-LINK). **Resolvido:** Pi-hole movido para **192.168.0.117** (CT117); **.115** fica para o equipamento TP-LINK com IP fixo.
- **192.168.0.117** — **CT117 `pihole6`** (MAC `bc:24:11:01:70:73` após clone Proxmox).
- **AMPAK Technology** — comum em **módulos Wi‑Fi embarcados** (IoT/câmaras).
- **Hon Hai** — fabricante de NICs (estações de trabalho).
- **Seiko Epson** — **192.168.0.61** (impressora).
- **Tecvan Informatica** — **192.168.0.210**.

### Inventário ARP (IP → MAC → vendor)

Ver output bruto na secção “Anexo” abaixo ou reexecutar no host.

## LAN 192.168.60.0/24 (eth1)

| Método | Hosts up |
|--------|----------|
| `arp-scan` | **6** + próprio host |
| `nmap -sn` | **7** (inclui 192.168.60.108) |
| `fping` | **7** |

Endereços vistos: `.101`, `.102`, `.110`, `.111`, `.114`, `.202` (+ `.108` local). MACs `bc:24:11:*` dominantes — consistente com **CTs no mesmo site Proxmox**.

## Conclusões

1. **Dois domínios de broadcast:** `192.168.0.0/24` (LAN principal, ~45 nós ICMP-up) e `192.168.60.0/24` (pequeno conjunto de CTs/serviços, 7 nós).
2. **Tailscale** oferece visibilidade completa do tailnet; problemas locais de DNS/rotas devem ser revistos se se pretender usar **subnets routes** neste CT.
3. **VMID ↔ IP (AGLSRV6, actualizado):** Pi-hole = **CT117** @ **192.168.0.117** (`pihole6`). Opcional: rever `pct list` / leases para outras entradas `bc:24:11:*`; port scan seletivo (`-sS` + lista de portas) apenas com autorização explícita.

---

## Anexo — saída bruta (arp-scan)

### eth0

Planilha Excel (mesma pasta): [`network-discovery-agldv06-eth0.xlsx`](network-discovery-agldv06-eth0.xlsx) — colunas IPv4, MAC, fabricante (OUI), ordenado por IP. **Nota:** linhas **`.115` / `.117`** foram actualizadas em 2026-04-04 para reflectir a migração Pi-hole → CT117.

```
192.168.0.1	24:e4:ce:8f:21:89	(Unknown)
192.168.0.18	bc:24:11:8e:e8:8b	(Unknown)
192.168.0.40	10:98:36:fd:b9:98	Dell Inc.
192.168.0.30	76:27:5f:fe:fa:f6	(Unknown: locally administered)
192.168.0.24	bc:38:98:0f:5e:29	(Unknown)
192.168.0.48	26:0c:10:5a:e2:f8	(Unknown: locally administered)
192.168.0.22	94:53:30:fe:76:c5	Hon Hai Precision Ind. Co.,Ltd.
192.168.0.28	94:53:30:fe:78:2d	Hon Hai Precision Ind. Co.,Ltd.
192.168.0.101	bc:24:11:7d:07:e4	(Unknown)
192.168.0.102	bc:24:11:1c:f7:c9	(Unknown)
192.168.0.20	b8:13:32:b8:78:3c	AMPAK Technology,Inc.
192.168.0.17	0e:a6:03:5c:51:66	(Unknown: locally administered)
192.168.0.43	50:41:1c:44:f4:2c	AMPAK Technology,Inc.
192.168.0.46	70:f7:54:fe:52:25	AMPAK Technology,Inc.
192.168.0.109	bc:24:11:77:89:61	(Unknown)
192.168.0.45	b8:13:32:43:15:9c	AMPAK Technology,Inc.
192.168.0.110	bc:24:11:17:01:3a	(Unknown)
192.168.0.111	bc:24:11:82:7f:dc	(Unknown)
192.168.0.114	bc:24:11:54:fb:f1	(Unknown)
192.168.0.115	cc:32:e5:bf:c0:06	TP-LINK TECHNOLOGIES CO.,LTD. (IP fixo; sem Pi-hole)
192.168.0.117	bc:24:11:01:70:73	Proxmox CT117 pihole6 (ex-MAC .115 bc:24:11:3f:6a:b3)
192.168.0.180	20:47:47:fc:4e:c2	Dell Inc.
192.168.0.181	84:7b:eb:e5:2f:05	Dell Inc.
192.168.0.182	84:7b:eb:e5:2e:0a	Dell Inc.
192.168.0.183	84:7b:eb:e5:23:19	Dell Inc.
192.168.0.185	84:7b:eb:e5:24:7f	Dell Inc.
192.168.0.187	84:7b:eb:e5:24:a7	Dell Inc.
192.168.0.191	84:7b:eb:e5:2f:18	Dell Inc.
192.168.0.193	84:7b:eb:e5:2f:1a	Dell Inc.
192.168.0.195	d0:94:66:b6:b1:66	Dell Inc.
192.168.0.200	bc:24:11:db:71:e8	(Unknown)
192.168.0.202	22:33:4d:06:cd:b7	(Unknown: locally administered)
192.168.0.203	bc:24:11:c5:75:a8	(Unknown)
192.168.0.210	00:1d:5b:01:95:9d	Tecvan Informatica Ltda
192.168.0.212	60:32:b1:ac:96:30	TP-LINK TECHNOLOGIES CO.,LTD.
192.168.0.231	bc:24:11:c5:9a:ea	(Unknown)
192.168.0.233	c0:47:0e:f6:f7:69	(Unknown)
192.168.0.234	74:e6:e2:d0:2a:79	Dell Inc.
192.168.0.190	dc:45:46:99:04:c1	(Unknown)
192.168.0.27	46:5c:a4:20:ba:54	(Unknown: locally administered)
192.168.0.34	8a:72:bf:38:8b:f1	(Unknown: locally administered)
192.168.0.61	44:d2:44:0c:bf:3c	Seiko Epson Corporation
192.168.0.89	94:53:30:fe:6d:0f	Hon Hai Precision Ind. Co.,Ltd.
```

### eth1

```
192.168.60.101	bc:24:11:7c:97:fe	(Unknown)
192.168.60.102	bc:24:11:8c:ef:45	(Unknown)
192.168.60.110	bc:24:11:a7:68:31	(Unknown)
192.168.60.111	bc:24:11:07:ee:37	(Unknown)
192.168.60.114	bc:24:11:e5:a7:81	(Unknown)
192.168.60.202	be:d4:4b:7b:0c:4f	(Unknown: locally administered)
```

---

## Comando para repetir a recolha

```bash
ssh root@100.71.229.12 'arp-scan -I eth0 --localnet; arp-scan -I eth1 --localnet; nmap -sn 192.168.0.0/24; nmap -sn 192.168.60.0/24; tailscale status'
```
