# Build Options for Hydravion

## Option 1: Python Script ✅

**Works on:** All systems (Linux, macOS, Windows) and all shells (bash, fish, zsh, PowerShell)

### Setup
```bash
# No setup needed - Python 3 is usually pre-installed
```

### Usage
```bash
# Set environment variables (works in any shell)
export ROKU_DEV_TARGET=your_roku_ip
export DEVPASSWORD=your_password  # Optional

# Or in fish:
set -x ROKU_DEV_TARGET your_roku_ip
set -x DEVPASSWORD your_password

# Build commands
python3 roku_build.py pkg             # Create package file
python3 roku_build.py install         # Install app
python3 roku_build.py remove          # Remove app
python3 roku_build.py run             # Remove and install
python3 roku_build.py check-target    # Check Roku connection
```

### Advantages
- ✅ Works on all systems and shells
- ✅ Better environment variable handling
- ✅ Clearer error messages
- ✅ No make/shell compatibility issues
- ✅ Easier to debug and modify

---
