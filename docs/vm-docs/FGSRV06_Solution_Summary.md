# FGSRV06 SSH Connection & Mono Warning Resolution
## Mission Complete ✅

### 1. SSH Configuration Added
**Location:** `/root/.ssh/config` (lines 145-156)
```
Host FGSRV06
  HostName 186.202.57.120
  User root
  IdentityFile ~/.ssh/fg_srv.pem
```

**Connection Test:**
```bash
ssh FGSRV06 "echo 'Connected!'"
```

### 2. Mono Warning Fixed
**Problem:** Deprecated GPG key storage in legacy trusted.gpg keyring

**Solution Applied:**
```bash
# Export mono GPG key to modern location
sudo apt-key export 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF | \
  sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/mono-official.gpg
```

**Result:** No more deprecation warnings in `apt update`

### 3. Quick Commands
```bash
# Connect to FGSRV06
ssh FGSRV06

# Run apt upgrade without warnings
ssh FGSRV06 "sudo apt update && sudo apt upgrade -y"

# Check for warnings
ssh FGSRV06 "sudo apt update 2>&1 | grep -i warn"
```

### 4. Files Created
- `/root/fix_fgsrv06_mono.sh` - Automated fix script
- `/root/.ssh/config` - Updated with FGSRV06 entry

### Status: ✅ All objectives completed successfully