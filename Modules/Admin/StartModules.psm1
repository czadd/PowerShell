###########################################################################################################################
# Functions to load various modules. Each one has an alias as well to shorten typing.
###########################################################################################################################

Function Start-VirtualMachineManagerModule{
    If( ! (get-module virtualmachinemanager -ErrorAction SilentlyContinue) ){ 
        Import-module VirtualMachineManager #-force -global
    }
}
New-Alias -name vmm -Value Start-VirtualMachineManagerModule -description "StartModules"
Add-AdminHelp -AliasName vmm -Description "Start Virtual Machine Manager module" -Examples "1: svm;2: vm"

New-Alias -name sex -Value (Join-path $go.'msol and exchange' 'Start-MSOLconnectQuick.ps1') # -description "StartModules" 
Add-AdminHelp -AliasName sex -Description "Start Exhange Online session" -Examples "sex"

Function Connect-Compellent{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][ValidateSet('Prod','DR')][String]$Environment,
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)][String]$CompellentCredPath = (Join-path $env:APPDATA 'compellentcred.xml')
    )

    #Add-PSSnapin Compellent.StorageCenter.PSSnapin
    
    if( -not (Test-path $CompellentCredPath) ){
        $CompellentCred = Get-Credential -Message "Compellent Login"
        $CompellentCred | Export-Clixml -Path $CompellentCredPath
    }
    Else{
        $CompellentCred = Import-Clixml $CompellentCredPath
    }

    Switch( $Environment ){
        Prod{ $CompellentHost = '10.10.2.11'  }
        DR  { $CompellentHost = '10.10.20.2.11'  }
    }

    $Connection = Get-SCConnection -HostName $CompellentHost -User $CompellentCred.UserName $CompellentCred.Password -Save $Environment -Default
}

export-modulemember -function * -variable * -alias * -Cmdlet * 
