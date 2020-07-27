#Default values for cmdlets. For some reason these don't want to work from modules (.psm1 files)

$PSDefaultParameterValues = @{
    "get-aduser:Properties"="description","office","OfficePhone","msRTCSIP-PrimaryUserAddress","msRTCSIP-Line","MobilePhone","Description","AccountLockoutTime","Title","AccountExpirationDate","EmployeeId","Department";
    "get-adgroup:Properties"="mail","managedby","GroupCategory","GroupScope","DisplayName";
    "Send-MailMessage:SMTPServer" = "smtp.corporate.ncm";
    "get-ciminstance:ClassName"   = "Win32_ComputerSystem";
    "get-help:showwindow"         = $True;
    "get-adcomputer:properties"   = "OperatingSystem";
}
