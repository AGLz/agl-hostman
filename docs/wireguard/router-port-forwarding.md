# Router Port Forwarding Configuration
**Date**: 2025-10-15
**Objective**: Configure routers to forward WireGuard UDP traffic

## ⚠️ CRITICAL: Router Configuration Required

WireGuard está configurado para conectar diretamente pela internet, mas precisa de port forwarding nos roteadores de cada local.

## Router A (AGLSRV1 Location)

**IP Público**: 191.183.137.104
**IP Local AGLSRV1**: 192.168.0.245

### Configuração Necessária:

```
Protocol: UDP
External Port: 51820
Internal IP: 192.168.0.245
Internal Port: 51820
Description: WireGuard CT120
```

### Como Configurar:

1. Acesse o painel administrativo do router (geralmente 192.168.0.1 ou 192.168.1.1)
2. Navegue até **Port Forwarding** ou **Virtual Servers** ou **NAT**
3. Adicione uma nova regra:
   - Nome: `WireGuard-CT120`
   - Protocolo: `UDP`
   - Porta Externa: `51820`
   - IP Interno: `192.168.0.245` (AGLSRV1)
   - Porta Interna: `51820`
4. Salve e aplique as configurações
5. Reinicie o router se necessário

## Router B (AGLSRV6 Location)

**IP Público**: 189.100.68.34
**IP Local AGLSRV6**: (precisa verificar o IP local)

### Verificar IP Local do AGLSRV6:

```bash
ssh root@100.98.108.66 "ip addr show | grep 'inet ' | grep -v 127.0.0.1 | grep -v tailscale | grep -v 100."
```

### Configuração Necessária:

```
Protocol: UDP
External Port: 51821
Internal IP: <IP_LOCAL_AGLSRV6>
Internal Port: 51821
Description: WireGuard CT121
```

### Como Configurar:

1. Acesse o painel administrativo do router
2. Navegue até **Port Forwarding** ou **Virtual Servers** ou **NAT**
3. Adicione uma nova regra:
   - Nome: `WireGuard-CT121`
   - Protocolo: `UDP`
   - Porta Externa: `51821`
   - IP Interno: `<IP_LOCAL_AGLSRV6>`
   - Porta Interna: `51821`
4. Salve e aplique as configurações
5. Reinicie o router se necessário

## Verificação

Após configurar port forwarding em AMBOS os routers:

### Teste de Conectividade:

```bash
# De AGLSRV1 - testar porta aberta em AGLSRV6
nc -vuz 189.100.68.34 51821

# De AGLSRV6 - testar porta aberta em AGLSRV1
nc -vuz 191.183.137.104 51820
```

### Teste WireGuard:

```bash
# De CT120
ssh root@192.168.0.245 "pct exec 120 -- ping -c 4 10.6.0.3"

# De CT121
ssh root@100.98.108.66 "pct exec 121 -- ping -c 4 10.6.0.1"
```

## Troubleshooting

### Se não funcionar:

1. **Verificar Firewall do Router**:
   - Alguns routers têm firewall separado do port forwarding
   - Certifique-se que UDP 51820/51821 estão permitidos

2. **Verificar IP Estático**:
   - AGLSRV1/AGLSRV6 devem ter IPs locais fixos
   - Configure DHCP reservation no router se necessário

3. **Verificar Port Forwarding**:
   ```bash
   # Testar de fora da rede (use um servidor externo)
   nmap -sU -p 51820 191.183.137.104
   nmap -sU -p 51821 189.100.68.34
   ```

4. **Verificar WireGuard Status**:
   ```bash
   # CT120
   ssh root@192.168.0.245 "pct exec 120 -- wg show wg0"

   # CT121
   ssh root@100.98.108.66 "pct exec 121 -- wg show wg0"
   ```

5. **Verificar Logs**:
   ```bash
   # CT120
   ssh root@192.168.0.245 "pct exec 120 -- journalctl -u wg-quick@wg0 -n 50"

   # CT121
   ssh root@100.98.108.66 "pct exec 121 -- journalctl -u wg-quick@wg0 -n 50"
   ```

## Configuração Atual

### AGLSRV1 (CT120)
```
Interface: wg0
Address: 10.6.0.1/24
Listen Port: 51820
Public Key: Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo=

Peer: CT121 (AGLSRV6)
Public Key: tAq3Ec660PsqijieBEBUyIEidsacrdAQNzealHfRfBM=
Endpoint: 189.100.68.34:51821
Allowed IPs: 10.6.0.3/32
```

### AGLSRV6 (CT121)
```
Interface: wg0
Address: 10.6.0.3/24
Listen Port: 51821
Public Key: tAq3Ec660PsqijieBEBUyIEidsacrdAQNzealHfRfBM=

Peer: CT120 (AGLSRV1)
Public Key: Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo=
Endpoint: 191.183.137.104:51820
Allowed IPs: 10.6.0.0/24
```

## Port Forwarding nos Hosts Proxmox

Já configurado automaticamente:

### AGLSRV1:
```
UDP 51820 -> 192.168.0.120:51820 (CT120)
```

### AGLSRV6:
```
UDP 51821 -> 192.168.0.18:51821 (CT121)
```

## Próximos Passos

1. ✅ Port forwarding configurado nos hosts Proxmox
2. ⏳ **AÇÃO NECESSÁRIA**: Configurar port forwarding no Router A (AGLSRV1)
3. ⏳ **AÇÃO NECESSÁRIA**: Configurar port forwarding no Router B (AGLSRV6)
4. ⏳ Testar conectividade WireGuard
5. ⏳ Performance benchmarks

---

**Status**: Aguardando configuração dos routers
**Bloqueador**: Port forwarding nos routers precisa ser feito manualmente
**ETA**: 10-15 minutos após configuração dos routers
