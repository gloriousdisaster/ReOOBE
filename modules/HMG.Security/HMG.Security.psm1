#requires -version 5.1
<#
.SYNOPSIS
    FIXED Security module for HMG password encryption - handles cross-computer compatibility.

.DESCRIPTION
    This is a patched version that handles encoding issues when transferring blobs between computers.

.NOTES
    Version: 1.1 - Fixed for cross-computer compatibility
#>

Add-Type -AssemblyName System.Security

# Helper function to convert SecureString to plain text
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Secure
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Secure
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ConvertFrom-SecureStringPlain {
  param([System.Security.SecureString]$Secure)
  if (-not $Secure) { return $null }

  # Most reliable method: use NetworkCredential
  $cred = New-Object System.Management.Automation.PSCredential("dummy", $Secure)
  return $cred.GetNetworkCredential().Password
}

# Derive AES key from password using PBKDF2
function Get-KeyFromPassword {
  param(
    [SecureString]$Password,
    [byte[]]$Salt,
    [int]$KeyBytes = 32,
    [int]$Iterations = 100000
  )
  # Convert SecureString to plain text for PBKDF2
  $plainPassword = ConvertFrom-SecureStringPlain -Secure $Password
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($plainPassword)
  $pbkdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($bytes, $Salt, $Iterations)
  return $pbkdf.GetBytes($KeyBytes)
}

# Encrypt text with password
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER PlainText
Parameter description

.PARAMETER Password
Parameter description

.PARAMETER Iterations
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER PlainText
Parameter description

.PARAMETER Password
Parameter description

.PARAMETER Iterations
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Protect-TextWithPassword {
  param(
    [string]$PlainText,
    [SecureString]$Password,
    [int]$Iterations = 100000
  )

  # Validate inputs
  if ([string]::IsNullOrEmpty($PlainText)) {
    throw "PlainText cannot be null or empty"
  }
  if (-not $Password) {
    throw "Password cannot be null or empty"
  }

  # Generate random 16-byte salt
  $salt = New-Object byte[] 16
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)

  # Derive key from password
  $key = Get-KeyFromPassword -Password $Password -Salt $salt -Iterations $Iterations

  try {
    # Convert string to bytes
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)

    # Create AES object
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.GenerateIV()

    # Encrypt
    $encryptor = $aes.CreateEncryptor()
    $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)

    # Combine IV and encrypted data
    $combined = New-Object byte[] ($aes.IV.Length + $encryptedBytes.Length)
    [System.Array]::Copy($aes.IV, 0, $combined, 0, $aes.IV.Length)
    [System.Array]::Copy($encryptedBytes, 0, $combined, $aes.IV.Length, $encryptedBytes.Length)

    # Convert to base64
    $enc = [Convert]::ToBase64String($combined)

    # Clean up
    $aes.Dispose()
  }
  catch {
    throw "Encryption failed: $_"
  }

  if ([string]::IsNullOrEmpty($enc)) {
    throw "Encryption produced empty result"
  }

  # Return payload: Base64Salt::Iterations::EncryptedBlob
  return ([Convert]::ToBase64String($salt) + "::" + $Iterations + "::" + $enc)
}

# Decrypt text with password - FIXED VERSION
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Payload
Parameter description

.PARAMETER Password
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Payload
Parameter description

.PARAMETER Password
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Unprotect-TextWithPassword {
  param(
    [string]$Payload,
    [SecureString]$Password
  )

  # Clean the payload - remove any potential formatting issues
  $Payload = $Payload.Trim()

  # Handle potential encoding issues - remove any BOM or special chars
  $Payload = $Payload -replace '^\s*', '' -replace '\s*$', ''

  # Parse payload - try different splitting approaches
  $parts = $null

  # First try: standard split
  $parts = $Payload -split '::'

  # If that doesn't give us 3 parts, try to fix common issues
  if ($parts.Count -ne 3) {
    # Try removing potential quotes or extra characters
    $cleanPayload = $Payload -replace "^['\`"]|['\`"]$", ''
    $parts = $cleanPayload -split '::'
  }

  if ($parts.Count -ne 3) {
    # Last resort - try to extract the pattern manually
    if ($Payload -match '([A-Za-z0-9+/=]+)::(\d+)::([A-Za-z0-9+/=]+)') {
      $parts = @($matches[1], $matches[2], $matches[3])
    } else {
      throw "Invalid encrypted payload format. Expected format: base64::number::base64"
    }
  }

  try {
    $salt = [Convert]::FromBase64String($parts[0].Trim())
    $iterations = [int]$parts[1].Trim()
    $encrypted = $parts[2].Trim()
  } catch {
    throw "Failed to parse payload components: $_"
  }

  # Derive key from password
  $key = Get-KeyFromPassword -Password $Password -Salt $salt -Iterations $iterations

  try {
    # Decode from base64
    $combined = [Convert]::FromBase64String($encrypted)

    # Extract IV and encrypted data
    $ivLength = 16  # AES IV is always 16 bytes
    $iv = New-Object byte[] $ivLength
    $encryptedBytes = New-Object byte[] ($combined.Length - $ivLength)

    [System.Array]::Copy($combined, 0, $iv, 0, $ivLength)
    [System.Array]::Copy($combined, $ivLength, $encryptedBytes, 0, $encryptedBytes.Length)

    # Create AES object
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = $iv

    # Decrypt
    $decryptor = $aes.CreateDecryptor()
    $plainBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)

    # Convert bytes to string
    $plainText = [System.Text.Encoding]::UTF8.GetString($plainBytes)

    # Clean up
    $aes.Dispose()

    return $plainText
  }
  catch {
    # Return null instead of throwing to allow checking
    return $null
  }
}

# Decrypt a hashtable of role passwords - FIXED VERSION
function Unprotect-RolePasswords {
  param(
    [string]$EncryptedFile,
    [SecureString]$MasterPassword
  )

  if (-not (Test-Path $EncryptedFile)) {
    throw "Encrypted file not found: $EncryptedFile"
  }

  # Try multiple methods to read the file
  $encryptedData = $null

  # Method 1: Standard Import-PowerShellDataFile
  try {
    $encryptedData = Import-PowerShellDataFile $EncryptedFile
  } catch {
    Write-Warning "Standard import failed, trying alternative method..."

    # Method 2: Manual parsing
    $content = Get-Content $EncryptedFile -Raw

    # Remove BOM if present
    $content = $content -replace '^\xEF\xBB\xBF', ''

    # Try to parse manually
    if ($content -match '@\{([^}]+)\}') {
      $hashContent = $matches[1]
      $encryptedData = @{}

      # Extract each role
      $pattern = "(\w+)\s*=\s*['\`"]([^'\`"]+)['\`"]"
      $roleMatches = [regex]::Matches($hashContent, $pattern)

      foreach ($match in $roleMatches) {
        $role = $match.Groups[1].Value
        $payload = $match.Groups[2].Value
        $encryptedData[$role] = $payload
      }
    }

    if (-not $encryptedData -or $encryptedData.Count -eq 0) {
      throw "Could not parse encrypted file in any format"
    }
  }

  $decrypted = @{}
  $successCount = 0

  foreach ($role in $encryptedData.Keys) {
    $payload = $encryptedData[$role]

    # Clean the payload
    $payload = $payload.Trim()

    try {
      $decryptedPassword = Unprotect-TextWithPassword -Payload $payload -Password $MasterPassword
      if ($decryptedPassword) {
        $decrypted[$role] = $decryptedPassword
        $successCount++
      } else {
        Write-Warning "Failed to decrypt password for role: $role"
        $decrypted[$role] = $null
      }
    } catch {
      Write-Warning "Error decrypting $role : $_"
      $decrypted[$role] = $null
    }
  }

  # If no passwords were successfully decrypted, the master password is wrong
  if ($successCount -eq 0 -and $encryptedData.Count -gt 0) {
    throw "Failed to decrypt any passwords - incorrect master password or corrupted file"
  }

  return $decrypted
}

# Encrypt a hashtable of role passwords
function Protect-RolePasswords {
  param(
    [hashtable]$Passwords,
    [SecureString]$MasterPassword,
    [string]$OutputFile
  )

  if (-not $MasterPassword) {
    throw "Master password cannot be null or empty"
  }

  $encrypted = @{}

  foreach ($role in $Passwords.Keys) {
    $rolePassword = $Passwords[$role]
    Write-Host "Encrypting password for role: $role" -ForegroundColor Cyan

    if ([string]::IsNullOrEmpty($rolePassword)) {
      Write-Host "  WARNING: Password for $role is null or empty, skipping" -ForegroundColor Yellow
      continue
    }

    Write-Host "  Password length: $($rolePassword.Length) characters" -ForegroundColor DarkGray

    try {
      $encrypted[$role] = Protect-TextWithPassword -PlainText $rolePassword -Password $MasterPassword
      Write-Host "  [OK] Encrypted successfully" -ForegroundColor Green
    }
    catch {
      Write-Host "  [ERROR] Encryption failed: $_" -ForegroundColor Red
      throw
    }
  }

  if ($encrypted.Count -eq 0) {
    throw "No passwords were encrypted successfully"
  }

  # Save as PowerShell data file with consistent formatting
  $content = "@{`r`n"
  foreach ($role in $encrypted.Keys | Sort-Object) {
    $content += "    $role = '$($encrypted[$role])'`r`n"
  }
  $content += "}"

  # Write with UTF-8 no BOM for maximum compatibility
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($OutputFile, $content, $utf8NoBom)

  Write-Host "`nEncrypted passwords saved to: $OutputFile" -ForegroundColor Green
}

# Get master password from user or environment variable
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Force
Parameter description

.PARAMETER EnvironmentVariable
Parameter description

.PARAMETER ReturnSecureString
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Force
Parameter description

.PARAMETER EnvironmentVariable
Parameter description

.PARAMETER ReturnSecureString
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-MasterPassword {
  param(
    [switch]$Force,
    [string]$EnvironmentVariable = 'HMG_MASTER_PASSWORD',
    [switch]$ReturnSecureString
  )

  # Check environment variable first
  if (-not $Force) {
    $envPassword = [System.Environment]::GetEnvironmentVariable($EnvironmentVariable)
    if ($envPassword) {
      Write-Host "Using master password from environment variable: $EnvironmentVariable" -ForegroundColor Gray
      if ($ReturnSecureString) {
        return ConvertTo-SecureString -String $envPassword -AsPlainText -Force
      }
      return $envPassword
    }
  }

  # Prompt user
  $secure = Read-Host "Enter master password" -AsSecureString

  # Validate that something was entered
  if ($null -eq $secure -or $secure.Length -eq 0) {
    Write-Host "ERROR: Master password cannot be empty" -ForegroundColor Red
    return $null
  }

  # Return SecureString or plain text based on parameter
  if ($ReturnSecureString) {
    return $secure
  }
  else {
    $plainPassword = ConvertFrom-SecureStringPlain -Secure $secure
    if ([string]::IsNullOrEmpty($plainPassword)) {
      Write-Host "ERROR: Failed to convert password" -ForegroundColor Red
      return $null
    }
    return $plainPassword
  }
}

# NOTE: Get-RolePassword function removed - now provided by HMG.Core
# Steps should call Get-RolePassword from HMG.Core which retrieves from HMGState cache
# The orchestrator calls Unprotect-RolePasswords once and stores in HMGState

Export-ModuleMember -Function @(
  'Protect-TextWithPassword',
  'Unprotect-TextWithPassword',
  'Protect-RolePasswords',
  'Unprotect-RolePasswords',
  'Get-MasterPassword',
  'ConvertFrom-SecureStringPlain'
)
