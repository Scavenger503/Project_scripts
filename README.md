# Universal SMB Diagnostic Tool

A cross-platform SMB self-check and mapping utility designed for Windows, macOS, and Linux environments.

## 🔧 Features
- Detects SMB support and status on all major OS platforms
- Supports share mounting via:
  - Windows: `net use`
  - macOS: `mount_smbfs`
  - Linux: `mount -t cifs`
- Encrypted credential handling (uses Python `cryptography` lib)
- Network port and share availability checks
- Interactive terminal prompts with error feedback

## 🚀 Platforms Supported
- ✅ Windows 10/11
- ✅ macOS (10.15+)
- ✅ Linux (Debian, Ubuntu, Fedora, Arch, etc.)

## 📦 Requirements
- Python 3.6+
- `cryptography` module (`pip install cryptography`)

## 📁 Usage
```bash
python3 Universal_SMB_Tool.py
```

Follow the on-screen instructions to test and mount SMB shares.

## 📄 License
MIT License - see `LICENSE` file.

## 📜 Changelog
See [CHANGELOG.md](./CHANGELOG.md) for full version history.

---

## 🛠️ Installation Guide (For Non-Technical Users)

### 🔷 Windows 11

1. **Install Python 3:**
   - Visit the official website: [https://www.python.org/downloads/windows/](https://www.python.org/downloads/windows/)
   - Download the latest version for Windows
   - Run the installer and make sure to **check the box that says "Add Python to PATH"** before clicking "Install Now"

2. **Install the Cryptography Module:**
   - Press `Windows + R`, type `cmd`, and press Enter
   - In the command prompt, type:
     ```bash
     pip install cryptography
     ```

---

### 🍏 macOS

1. **Install Homebrew (if not already installed):**
   - Open the **Terminal** and paste:
     ```bash
     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
     ```

2. **Install Python 3:**
   ```bash
   brew install python
   ```

3. **Install the Cryptography Module:**
   ```bash
   pip3 install cryptography
   ```

---

If you encounter any problems, contact: **support@worldofhackers.io**
