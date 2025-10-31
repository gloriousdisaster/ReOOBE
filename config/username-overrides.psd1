@{
  # Machine-specific username overrides
  # Format: 'COMPUTERNAME' = @{ Role = 'username' }
  #
  # These override the default username generation for specific machines
  # Leave empty to use default behavior (computer name or settings.psd1 value)

  # Examples:
  # 'CH-505E-POS01' = @{
  #     Username = 'SpecialPOSUser'  # Override for this specific POS machine
  # }
  #
  # 'OFFICE-MGR-01' = @{
  #     Username = 'JohnDoe'          # Specific manager's machine
  # }

  # Active overrides (uncomment and modify as needed):
  Overrides = @{
    # 'COMPUTER-NAME' = @{ Username = 'CustomUser' }
  }
}
