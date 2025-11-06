# WireGuard Mesh - IP Allocation
**Date**: 2025-10-16
**Hub**: FGSRV6 (186.202.57.120:51823)

## IP Address Plan (10.6.0.0/24)

### Hub
| IP | Hostname | Type | Public Key | Status |
|----|----------|------|------------|--------|
| 10.6.0.5 | FGSRV6 | Hub | Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8= | ✅ Active |

### Containers
| IP | Hostname | Location | Public Key | Status |
|----|----------|----------|------------|--------|
| 10.6.0.1 | CT120 | AGLSRV1 | Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo= | ✅ Active |
| 10.6.0.3 | CT121 | AGLSRV6 | tAq3Ec660PsqijieBEBUyIEidsacrdAQNzealHfRfBM= | ✅ Active |
| 10.6.0.4 | FGSRV5 | - | H4ENZ3PkJ0fNGpo0mM4AfB4rh+g5MI+ogz8DQQnZLwk= | ⏳ Pending |
| 10.6.0.14 | CT113 | AGLSRV6 | Q9eoIXok1VP4r+hn3Hix8V0LUHPA33xfynH80lnPj2U= | ⏳ Pending |
| 10.6.0.15 | CT172 | AGLSRV6b | ipPZKR/SM+HP/HNcBC2KEMSmHjX0nr7nXE+ee0TIeVo= | ⏳ Pending |

### Proxmox Hosts
| IP | Hostname | Public Key | Status |
|----|----------|------------|--------|
| 10.6.0.10 | AGLSRV1 | eqZp7/vSmjYn/sCN53xVXrguVHMVqdEvBu+m3Y60D0o= | ✅ Active |
| 10.6.0.11 | FGSRV5 | PZbaLhHorMAmxvTd+8QQHkNhhGKJ52yNwNMj0JpKWms= | ✅ Active |
| 10.6.0.12 | AGLSRV6 | j1r5kjpucqemhdV+7tbmtkGxr4isk0BUJHxJHVR1oCA= | ✅ Active |
| 10.6.0.13 | AGLSRV6b | srHVNaN9C9USqOBIHCtRLcn0MkJFhylXEoIsLpmgL34= | ⏳ Pending |
| 10.6.0.16 | FGSRV4 | j7Zruaj/9+ZxuRvTb8cHODjsBBoCXKkbjzyYQNK/ngo= | ⏳ Pending |
| 10.6.0.17 | AGLSRV5 | 0LPgHmSuTGqe7767xxyCfOJiTq8B0C5ZOTkGtgL9m0s= | ⏳ Pending |

## Current Status
- **Active Nodes**: 7
- **Pending Nodes**: 6
- **Total Capacity**: 13 nodes (expandable to 254)

## Port Allocation
- FGSRV6 Hub: 51823
- CT120: 51820
- CT121: 51821
- FGSRV5: 51822
- AGLSRV1: 51810
- FGSRV5 host: 51811
- AGLSRV6: 51812
- AGLSRV6b: 51813
- CT113: 51814
- CT172: 51815
- FGSRV4: 51816
- AGLSRV5: 51817

## Next Steps
1. Configure remaining nodes
2. Update FGSRV6 hub configuration
3. Test connectivity
4. Performance benchmarks
