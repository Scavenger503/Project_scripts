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

Maintained by **World of Hackers LLC** • Built by **Scavenger**
