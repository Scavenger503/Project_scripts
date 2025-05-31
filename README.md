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

## 🖼️ Screenshots

### 🪟 Windows 11
![Windows Diagnostics](images/Win_Universal_SMB_Tool_Patched_Final_part1.png)
![Windows Mapping](images/Win_Universal_SMB_Tool_Patched_Final_part2.png)

### 🐧 Linux (Ubuntu 25.04)
![Linux Output](images/Linux_Universal_Tool_Results_patched_Final.png)

### 🍏 macOS (Darwin 24.5)
![macOS Output](images/macOS_Universal_SMB_Tool_Patch_Results.png)

## 📦 Requirements
- Python 3.6+
- `cryptography` module

## 📁 Usage
```bash
python3 Universal_SMB_Tool.py
```

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
     pip install cryptography   # Use this on Windows
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
   pip3 install cryptography   # Use this on macOS
   ```

---

## 📄 License
MIT License - see `LICENSE` file.

## 📜 Changelog
See [CHANGELOG.md](./CHANGELOG.md) for full version history.

---

If you encounter any problems, contact: **support@worldofhackers.io**
