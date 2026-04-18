# WiFi Modules Build Troubleshooting Guide

## Common Issues and Solutions

### Issue 1: Only compat.ko is Generated

**Symptoms:**
- Build completes but only `compat.ko` is created
- Expected WiFi driver modules (mt7921*.ko, rtl8xxxu.ko, etc.) are missing

**Root Causes:**
1. **Incomplete backports configuration**: The `.config` file doesn't have all driver dependencies enabled
2. **Missing kernel symbols**: Required kernel options not enabled in kernel config
3. **Build ordering issues**: Module dependencies not satisfied

**Solutions:**

See the fixed YAML workflow and build script for proper configuration.

Key fixes:
- Enable CONFIG_MT76_CORE (required for MT drivers)
- Enable CONFIG_RTW88_CORE (required for RTW drivers)
- Build core modules before drivers
- Use proper dependency chain

### Issue 2: Build Fails with Symbol Errors

**Symptoms:**
```
ERROR: modpost: "ieee80211_*" undefined!
ERROR: modpost: "cfg80211_*" undefined!
```

**Solution:**
Ensure kernel is properly prepared with modules_prepare and all wireless configs enabled.

### Issue 3: CFI/LTO Compatibility Errors

**Solution:**
Disable CFI and LTO in kernel config:
```bash
./scripts/config --disable CONFIG_CFI_CLANG
./scripts/config --disable CONFIG_LTO_CLANG
```

For complete troubleshooting, see the scripts provided.
