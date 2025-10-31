# HMG Security Vault

## 🔐 Secure Credential Storage

This vault directory contains encrypted and plain-text credentials for the HMG Role-Based Configuration Management System.

## ⚠️ CRITICAL SECURITY WARNING

**NEVER commit actual credential files to version control!**

The `.gitignore` file ensures vault contents are excluded from Git, but always verify before committing.

## Directory Structure

```
vault/
├── blobs/          # Encrypted credential vaults
│   └── vault.blob  # AES-256 encrypted role passwords
├── clear/          # Plain-text credentials (DEVELOPMENT ONLY)
│   └── vault.txt   # Unencrypted passwords - DELETE IN PRODUCTION
└── README.md       # This file
```

## Vault Files

### `/blobs/vault.blob`
- **Purpose**: Production credential storage
- **Format**: PowerShell hashtable with AES-256 encrypted passwords
- **Encryption**: PBKDF2 (100,000 iterations) + AES-256-CBC
- **Structure**: `SALT::ITERATIONS::ENCRYPTED_DATA`
- **Required**: Master password for decryption

### `/clear/vault.txt`
- **Purpose**: Development/testing ONLY
- **Format**: Plain text `ROLE=password`
- **Security**: NONE - human readable
- **Usage**: Convert to encrypted blob before production

## Usage

### Creating an Encrypted Vault

```powershell
# From RBCMS root directory
.\scripts\security\Protect-HMGPasswords.ps1

# Or from a plain text file
.\scripts\security\Protect-HMGPasswords.ps1 -PasswordFile .\vault\clear\vault.txt -OutputFile .\vault\blobs\vault.blob
```

### Configuration

In `config\settings.psd1`:
```powershell
# For encrypted vault (production)
PasswordMode = 'Encrypted'
EncryptedPasswordFile = '.\vault\blobs\vault.blob'

# For plain text (development only)
PasswordMode = 'PlainText'
LocalUsersPasswords = @{
    POS   = @{ Pass = 'password' }
    MGR   = @{ Pass = 'password' }
    # etc...
}
```

### Using in Scripts

The framework automatically handles vault decryption when you run:
```powershell
# Set master password (or will prompt)
$env:HMG_MASTER_PASSWORD = "YourMasterPassword"

# Run setup
.\scripts\Invoke-Setup.ps1 -Role POS
```

## Security Best Practices

### 1. File Security
- Set restrictive NTFS permissions (Administrators only)
- Enable file system auditing on vault directory
- Use BitLocker or similar for disk encryption
- Never copy vault files to network shares

### 2. Master Password
- Minimum 15 characters with complexity
- Store separately from vault files
- Use different master passwords per environment
- Rotate master password quarterly
- Consider using Windows Credential Manager

### 3. Credential Rotation
- Change role passwords monthly
- Re-encrypt vault after password changes
- Keep previous vault versions (encrypted) for rollback
- Document rotation in change management system

### 4. Access Control
- Limit vault access to automation accounts
- Use separate vaults for different environments
- Implement break-glass procedures for emergency access
- Log all vault access attempts

### 5. Deployment Security
- Never transmit vault files via email/chat
- Use secure file transfer (SCP/SFTP) if needed
- Verify file integrity with checksums
- Clear credentials from memory after use

## Vault Management Commands

### Test Vault Decryption
```powershell
.\scripts\security\Test-HMGPasswords.ps1
```

### Clear Password Cache
```powershell
Import-Module .\modules\HMG.Security
Clear-PasswordCache
```

### Verify Vault Integrity
```powershell
.\scripts\security\Test-HMGPasswords.ps1 -ValidateOnly
```

## Emergency Procedures

### Lost Master Password
1. Cannot decrypt existing vault
2. Reset all role passwords immediately
3. Create new vault with new master password
4. Deploy to all systems
5. Document incident

### Compromised Vault
1. Assume all passwords compromised
2. Change all passwords immediately
3. Create new vault with new master password
4. Audit all system access logs
5. Implement additional monitoring

### Corrupted Vault
1. Restore from secure backup
2. If no backup, recreate from documentation
3. Verify all role passwords still valid
4. Test on non-production system first
5. Document recovery steps taken

## Compliance Notes

- Meets industry standards for password encryption
- PBKDF2 iterations exceed NIST recommendations
- AES-256 approved for classified information
- Implements defense-in-depth security model
- Supports audit and compliance requirements

## Support

For issues or questions about the vault system:
1. Check documentation in `/docs`
2. Review scripts in `/scripts/security`
3. Contact system administrator
4. Submit issue to project repository

---

**Remember**: The vault contains the keys to your kingdom. Protect it accordingly.

## Version History

- **2.0.0** (2025-10-27): Migrated from security/secrets to vault structure
- **1.0.0** (2025-10-20): Initial implementation with PBKDF2+AES-256
