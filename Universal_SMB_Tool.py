#!/usr/bin/env python3
"""
Universal SMB Self-Check Tool
Cross-platform SMB diagnostic and mapping utility for Windows, macOS, and Linux
"""

import os
import sys
import platform
import subprocess
import socket
import getpass
import base64
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import json
import tempfile
import shutil

class SMBDiagnosticTool:
    def __init__(self):
        self.os_type = platform.system().lower()
        self.results = {}
        self.encryption_key = None
        
    def print_header(self):
        """Print tool header with system information"""
        print("=" * 60)
        print("       UNIVERSAL SMB DIAGNOSTIC TOOL")
        print("=" * 60)
        print(f"Operating System: {platform.system()} {platform.release()}")
        print(f"Architecture: {platform.machine()}")
        print(f"Python Version: {platform.python_version()}")
        print("=" * 60)
        print()

    def check_dependencies(self):
        """Check if required dependencies are available"""
        print("🔍 Checking dependencies...")
        dependencies = {
            'cryptography': False,
            'smbclient': False  # For advanced SMB operations
        }
        
        try:
            import cryptography
            dependencies['cryptography'] = True
            print("✅ Cryptography library: Available")
        except ImportError:
            print("❌ Cryptography library: Missing")
            print("   Install with: pip install cryptography")
            
        # Check for system SMB tools
        smb_tools = self.check_smb_tools()
        print(f"{'✅' if smb_tools else '❌'} SMB system tools: {'Available' if smb_tools else 'Missing'}")
        
        return dependencies['cryptography'] and smb_tools

    def check_smb_tools(self):
        """Check for platform-specific SMB tools"""
        if self.os_type == 'windows':
            return self.check_windows_smb()
        elif self.os_type == 'darwin':  # macOS
            return self.check_macos_smb()
        elif self.os_type == 'linux':
            return self.check_linux_smb()
        return False

    def check_windows_smb(self):
        """Check Windows SMB services and features"""
        print("\n🔍 Checking Windows SMB configuration...")
        
        # Check SMB services
        services_to_check = [
            'LanmanServer',     # Server service
            'LanmanWorkstation' # Workstation service
        ]
        
        service_status = {}
        for service in services_to_check:
            try:
                result = subprocess.run(
                    ['sc', 'query', service],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                if result.returncode == 0:
                    if 'RUNNING' in result.stdout:
                        service_status[service] = 'Running'
                        print(f"✅ {service}: Running")
                    else:
                        service_status[service] = 'Stopped'
                        print(f"❌ {service}: Stopped")
                        print(f"   To start: sc start {service}")
                else:
                    service_status[service] = 'Not found'
                    print(f"❌ {service}: Not found")
            except Exception as e:
                service_status[service] = f'Error: {str(e)}'
                print(f"❌ {service}: Error checking - {str(e)}")
        
        # Check SMB features
        self.check_windows_features()
        
        self.results['windows_services'] = service_status
        return any(status == 'Running' for status in service_status.values())

    def check_windows_features(self):
        """Check Windows SMB features"""
        print("\n🔍 Checking Windows SMB features...")
        
        features_to_check = [
            'SMB1Protocol',
            'SMB1Protocol-Client',
            'SMB1Protocol-Server'
        ]
        
        try:
            result = subprocess.run(
                ['powershell', '-Command', 'Get-WindowsOptionalFeature -Online | Where-Object {$_.FeatureName -like "*SMB*"} | Select-Object FeatureName, State'],
                capture_output=True,
                text=True,
                timeout=15
            )
            
            if result.returncode == 0:
                print("📋 SMB Features status:")
                print(result.stdout)
            else:
                print("⚠️  Could not check SMB features (requires admin privileges)")
                
        except Exception as e:
            print(f"⚠️  Error checking SMB features: {str(e)}")

    def check_macos_smb(self):
        """Check macOS SMB configuration"""
        print("\n🔍 Checking macOS SMB configuration...")
        
        # Check if SMB is available
        try:
            result = subprocess.run(['which', 'smbutil'], capture_output=True, text=True)
            if result.returncode == 0:
                print("✅ smbutil: Available")
                smb_available = True
            else:
                print("❌ smbutil: Not found")
                smb_available = False
        except Exception as e:
            print(f"❌ Error checking smbutil: {str(e)}")
            smb_available = False
            
        # Check SMB client service
        try:
            result = subprocess.run(
                ['launchctl', 'list', 'com.apple.smb.preferences'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print("✅ SMB client service: Running")
            else:
                print("⚠️  SMB client service: Status unknown")
        except Exception as e:
            print(f"⚠️  Error checking SMB service: {str(e)}")
            
        self.results['macos_smb'] = {'smbutil_available': smb_available}
        return smb_available

    def check_linux_smb(self):
        """Check Linux SMB configuration"""
        print("\n🔍 Checking Linux SMB configuration...")
        
        # Check for CIFS utilities
        tools = ['smbclient', 'mount.cifs', 'smbmount']
        available_tools = []
        
        for tool in tools:
            try:
                result = subprocess.run(['which', tool], capture_output=True, text=True)
                if result.returncode == 0:
                    print(f"✅ {tool}: Available")
                    available_tools.append(tool)
                else:
                    print(f"❌ {tool}: Not found")
            except Exception as e:
                print(f"❌ {tool}: Error checking - {str(e)}")
        
        if not available_tools:
            print("\n💡 To install SMB tools:")
            print("   Ubuntu/Debian: sudo apt-get install cifs-utils smbclient")
            print("   CentOS/RHEL: sudo yum install cifs-utils samba-client")
            print("   Fedora: sudo dnf install cifs-utils samba-client")
            
        self.results['linux_smb'] = {'available_tools': available_tools}
        return len(available_tools) > 0

    def test_network_connectivity(self, host, port=445):
        """Test network connectivity to SMB port"""
        print(f"\n🔍 Testing network connectivity to {host}:{port}...")
        
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((host, port))
            sock.close()
            
            if result == 0:
                print(f"✅ Port {port}: Open")
                return True
            else:
                print(f"❌ Port {port}: Closed or unreachable")
                return False
        except socket.gaierror as e:
            print(f"❌ DNS resolution failed: {str(e)}")
            return False
        except Exception as e:
            print(f"❌ Connection test failed: {str(e)}")
            return False

    def test_smb_connection(self, server, share=None):
        """Test SMB connection to server"""
        print(f"\n🔍 Testing SMB connection to {server}...")
        
        if self.os_type == 'windows':
            return self.test_windows_smb_connection(server, share)
        elif self.os_type == 'darwin':
            return self.test_macos_smb_connection(server, share)
        elif self.os_type == 'linux':
            return self.test_linux_smb_connection(server, share)
        
        return False

    def test_windows_smb_connection(self, server, share):
        """Test Windows SMB connection"""
        try:
            # List shares
            result = subprocess.run(
                ['net', 'view', f'\\\\{server}'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                print(f"✅ SMB connection to {server}: Success")
                print("📋 Available shares:")
                lines = result.stdout.split('\n')
                for line in lines:
                    if line.strip() and 'Disk' in line:
                        print(f"   {line.strip()}")
                return True
            else:
                print(f"❌ SMB connection to {server}: Failed")
                if result.stderr:
                    print(f"   Error: {result.stderr.strip()}")
                return False
                
        except Exception as e:
            print(f"❌ SMB connection test failed: {str(e)}")
            return False

    def test_macos_smb_connection(self, server, share):
        """Test macOS SMB connection"""
        try:
            result = subprocess.run(
                ['smbutil', 'view', f'//{server}'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                print(f"✅ SMB connection to {server}: Success")
                if result.stdout:
                    print("📋 Available shares:")
                    print(result.stdout)
                return True
            else:
                print(f"❌ SMB connection to {server}: Failed")
                if result.stderr:
                    print(f"   Error: {result.stderr.strip()}")
                return False
                
        except Exception as e:
            print(f"❌ SMB connection test failed: {str(e)}")
            return False

    def test_linux_smb_connection(self, server, share):
        """Test Linux SMB connection"""
        try:
            result = subprocess.run(
                ['smbclient', '-L', server, '-N'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                print(f"✅ SMB connection to {server}: Success")
                print("📋 Available shares:")
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'Disk' in line or 'IPC' in line:
                        print(f"   {line.strip()}")
                return True
            else:
                print(f"❌ SMB connection to {server}: Failed")
                if result.stderr:
                    print(f"   Error: {result.stderr.strip()}")
                return False
                
        except Exception as e:
            print(f"❌ SMB connection test failed: {str(e)}")
            return False

    def generate_encryption_key(self, password):
        """Generate encryption key from password"""
        password_bytes = password.encode()
        salt = b'smb_tool_salt_2024'  # In production, use a random salt
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(password_bytes))
        return Fernet(key)

    def encrypt_credentials(self, username, password, encryption_password):
        """Encrypt user credentials"""
        try:
            cipher = self.generate_encryption_key(encryption_password)
            credentials = {
                'username': username,
                'password': password
            }
            
            credentials_json = json.dumps(credentials)
            encrypted_data = cipher.encrypt(credentials_json.encode())
            
            return base64.urlsafe_b64encode(encrypted_data).decode()
        except Exception as e:
            print(f"❌ Error encrypting credentials: {str(e)}")
            return None

    def decrypt_credentials(self, encrypted_data, encryption_password):
        """Decrypt user credentials"""
        try:
            cipher = self.generate_encryption_key(encryption_password)
            encrypted_bytes = base64.urlsafe_b64decode(encrypted_data.encode())
            decrypted_data = cipher.decrypt(encrypted_bytes)
            
            credentials = json.loads(decrypted_data.decode())
            return credentials['username'], credentials['password']
        except Exception as e:
            print(f"❌ Error decrypting credentials: {str(e)}")
            return None, None

    def mount_smb_share(self, server, share, username, password, mount_point=None):
        """Mount SMB share based on OS"""
        print(f"\n🔍 Attempting to mount \\\\{server}\\{share}...")
        
        if self.os_type == 'windows':
            return self.mount_windows_smb(server, share, username, password)
        elif self.os_type == 'darwin':
            return self.mount_macos_smb(server, share, username, password, mount_point)
        elif self.os_type == 'linux':
            return self.mount_linux_smb(server, share, username, password, mount_point)
        
        return False

    def mount_windows_smb(self, server, share, username, password):
        """Mount SMB share on Windows"""
        try:
            # Find available drive letter
            used_drives = [f"{chr(i)}:" for i in range(ord('A'), ord('Z')+1) 
                          if os.path.exists(f"{chr(i)}:\\")]
            
            available_drives = [f"{chr(i)}:" for i in range(ord('Z'), ord('A')-1, -1) 
                               if f"{chr(i)}:" not in used_drives]
            
            if not available_drives:
                print("❌ No available drive letters")
                return False
                
            drive_letter = available_drives[0]
            unc_path = f"\\\\{server}\\{share}"
            
            # Create net use command
            cmd = ['net', 'use', drive_letter, unc_path]
            if username:
                cmd.extend([f'/user:{username}', password])
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            
            if result.returncode == 0:
                print(f"✅ Successfully mapped {unc_path} to {drive_letter}")
                print(f"   Access via: {drive_letter}\\")
                return True
            else:
                print(f"❌ Failed to map drive: {result.stderr.strip()}")
                return False
                
        except Exception as e:
            print(f"❌ Error mounting SMB share: {str(e)}")
            return False

    def mount_macos_smb(self, server, share, username, password, mount_point):
        """Mount SMB share on macOS"""
        try:
            if not mount_point:
                mount_point = f"/Volumes/{share}"
                
            # Create mount point if it doesn't exist
            os.makedirs(mount_point, exist_ok=True)
            
            # Build mount command
            if username and password:
                smb_url = f"smb://{username}:{password}@{server}/{share}"
            else:
                smb_url = f"smb://{server}/{share}"
            
            result = subprocess.run(
                ['mount', '-t', 'smbfs', smb_url, mount_point],
                capture_output=True,
                text=True,
                timeout=15
            )
            
            if result.returncode == 0:
                print(f"✅ Successfully mounted {server}/{share} to {mount_point}")
                return True
            else:
                print(f"❌ Failed to mount share: {result.stderr.strip()}")
                return False
                
        except Exception as e:
            print(f"❌ Error mounting SMB share: {str(e)}")
            return False

    def mount_linux_smb(self, server, share, username, password, mount_point):
        """Mount SMB share on Linux"""
        try:
            if not mount_point:
                mount_point = f"/mnt/{share}"
                
            # Create mount point if it doesn't exist
            os.makedirs(mount_point, exist_ok=True)
            
            # Create credentials file temporarily
            cred_content = f"username={username}\npassword={password}\n"
            
            with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.cred') as f:
                f.write(cred_content)
                cred_file = f.name
            
            try:
                # Mount command
                cmd = [
                    'sudo', 'mount', '-t', 'cifs',
                    f'//{server}/{share}',
                    mount_point,
                    '-o', f'credentials={cred_file},uid={os.getuid()},gid={os.getgid()}'
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
                
                if result.returncode == 0:
                    print(f"✅ Successfully mounted {server}/{share} to {mount_point}")
                    return True
                else:
                    print(f"❌ Failed to mount share: {result.stderr.strip()}")
                    return False
                    
            finally:
                # Clean up credentials file
                try:
                    os.unlink(cred_file)
                except:
                    pass
                    
        except Exception as e:
            print(f"❌ Error mounting SMB share: {str(e)}")
            return False

    def run_diagnostics(self):
        """Run comprehensive SMB diagnostics"""
        self.print_header()
        
        print("🚀 Starting SMB diagnostics...\n")
        
        # Check dependencies
        if not self.check_dependencies():
            print("\n❌ Critical dependencies missing. Please install required components.")
            return False
        
        # Check SMB services/tools
        smb_ready = self.check_smb_tools()
        
        if not smb_ready:
            print("\n❌ SMB services/tools not properly configured.")
            print("Please enable required SMB services before proceeding.")
            return False
        
        print("\n✅ All diagnostic checks passed!")
        return True

    def interactive_mapping(self):
        """Interactive SMB share mapping"""
        print("\n" + "="*60)
        print("           SMB SHARE MAPPING")
        print("="*60)
        
        # Get server information
        server = input("\nEnter server IP address or hostname: ").strip()
        if not server:
            print("❌ Server address is required.")
            return False
            
        share = input("Enter share name: ").strip()
        if not share:
            print("❌ Share name is required.")
            return False
        
        # Test connectivity first
        if not self.test_network_connectivity(server):
            print("❌ Cannot reach server. Please check network connectivity.")
            return False
        
        # Test SMB connection
        if not self.test_smb_connection(server):
            print("⚠️  SMB connection test failed, but attempting to proceed...")
        
        # Get credentials
        print("\n🔐 Enter credentials (press Enter for anonymous access):")
        username = input("Username: ").strip()
        
        if username:
            password = getpass.getpass("Password: ")
            
            # Encrypt credentials
            print("\nFor security, credentials will be encrypted.")
            encryption_password = getpass.getpass("Enter encryption password: ")
            
            encrypted_creds = self.encrypt_credentials(username, password, encryption_password)
            if encrypted_creds:
                print("✅ Credentials encrypted successfully.")
                print(f"Encrypted data: {encrypted_creds[:50]}...")
            else:
                print("❌ Failed to encrypt credentials.")
                return False
        else:
            password = ""
            encryption_password = ""
        
        # Attempt to mount
        mount_point = None
        if self.os_type in ['darwin', 'linux']:
            mount_point = input(f"\nEnter mount point (default: /mnt/{share} or /Volumes/{share}): ").strip()
        
        success = self.mount_smb_share(server, share, username, password, mount_point)
        
        if success:
            print(f"\n🎉 Successfully configured SMB access to \\\\{server}\\{share}")
        else:
            print(f"\n❌ Failed to configure SMB access to \\\\{server}\\{share}")
        
        return success

def main():
    """Main function"""
    try:
        tool = SMBDiagnosticTool()
        
        # Run diagnostics
        if tool.run_diagnostics():
            # If diagnostics pass, offer interactive mapping
            response = input("\nWould you like to map an SMB share now? (y/n): ").strip().lower()
            if response in ['y', 'yes']:
                tool.interactive_mapping()
        
        print("\n" + "="*60)
        print("SMB diagnostic tool completed.")
        print("="*60)
        
    except KeyboardInterrupt:
        print("\n\n🛑 Operation cancelled by user.")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
