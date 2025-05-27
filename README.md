# SMB Diagnostic Toolkit (Cross-Platform)

A lightweight and powerful set of diagnostic scripts for verifying SMB (Server Message Block) client functionality across **Linux**, **macOS**, and **Windows**.

These tools help IT admins, technicians, and advanced users quickly test SMB client readiness, service availability, port connectivity, and share access on their local machines.

---

##Supported Platforms

| Platform | Script                     | Format            |
|----------|----------------------------|-------------------|
| macOS    | `smb_check.sh`             | Bash Shell Script |
| Linux    | `smb_selftest_linux.sh`    | Bash Shell Script |
| Windows  | `WindowsSambaCheck.ps1`    | PowerShell Script |

---

##Features

- Detect missing SMB tools and services
- Validate port 445 availability (TCP test)
- Prompt for credentials or use guest access
- Attempt to mount or list shares
- Provide detailed logging and helpful error messages
- Supports manual or automated testing in enterprise environments

---

##Usage

### macOS / Linux

```bash
chmod +x smb_check.sh           # or smb_selftest_linux.sh
./smb_check.sh                  # or ./smb_selftest_linux.sh
```

###Windows (PowerShell)

```powershell
.\WindowsSambaCheck.ps1
```

Run from an elevated PowerShell prompt if required.

---

##Requirements

###macOS:
- `mount_smbfs` (built-in)
- `nc` (netcat – install via `brew install netcat` if missing)

###Linux:
- `smbclient`
- `cifs-utils`
- `nc` (netcat)

###Windows:
- PowerShell 5.1+
- SMB client enabled (default on most versions)

---

##Output

Each script provides:

- Color-coded `[OK]`, `[INFO]`, `[WARNING]`, and `[ERROR]` messages
- Remote server connectivity checks
- Share accessibility (guest or authenticated)
- Optional read/write validation (on macOS/Linux)

---

##Licensing

This toolkit is owned and maintained by **scavenger503** and **World of Hackers LLC**.

The software is protected under a proprietary license. Redistribution, rebranding, or resale is not permitted without written permission.

See the [`LICENSE`](LICENSE) file for full terms and conditions.

---

##Support

Need help resolving SMB issues, analyzing logs, or configuring NAS/Windows/macOS/Linux?

**SMB Troubleshooting & Remote Support** is available.

Contact us at [support@worldofhackers.io](mailto:support@worldofhackers.io) to get started.
