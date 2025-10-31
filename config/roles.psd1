@{
  # Each role is just a simple string now
  # The system will automatically run ALL + the specific role
  POS          = 'POS'
  MGR          = 'MGR'
  CAM          = 'CAM'
  STAFF        = 'STAFF'

  # Optional: Add descriptions for documentation
  Descriptions = @{
    POS   = 'Point of Sale terminal configuration'
    MGR   = 'Manager workstation configuration'
    CAM   = 'Camera system configuration'
    STAFF = 'Administrative staff workstation configuration'
  }

  # Note: STAFF is the computer role for administrative staff workstations
  # HavenAdmin is a local user account that gets created on ALL computers
}
