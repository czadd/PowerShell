$connectionstring = 'Server=Sql01\sma;Initial Catalog=Microsoft.MgmtSvc.Store;Trusted_Connection=True;'
Get-MgmtSvcAdminUser  -ConnectionString $connectionstring
Add-MgmtSvcAdminUser -ConnectionString $connectionstring -Principal 'czadd\SmaAdmins'
