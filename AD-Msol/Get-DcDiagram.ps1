#Generated using technique from https://evotec.xyz/easy-way-to-create-diagrams-using-powershell-and-pswritehtml/

$DomainControllers = Get-WinADForestControllers | Select Name, IpV4Address, Site, isGlobalCatalog, PDCEmulator, SchemaMaster, DomainNamingMaster,InfrastructureMaster
New-HTML -TitleText 'Domain Controllers' -UseCssLinks:$true -UseJavaScriptLinks:$true -FilePath $PSScriptRoot\Example.html {
    New-HTMLSection -HeaderText 'NCM Domain Controllers' {
        New-HTMLPanel {
            New-HTMLDiagram {
                New-DiagramOptionsInteraction -Hover $true
                #New-DiagramOptionsManipulation
                New-DiagramNode -Label 'Corporate.Ncm' -ImageType squareImage -Image 'https://devblogs.microsoft.com/wp-content/uploads/sites/43/2019/03/Azure-Active-Directory_COLOR.png'
                Foreach( $DC in $DomainControllers ){
                    
                   New-DiagramNode -Label $Dc.Name -To 'Corporate.Ncm' -ImageType squareImage -Image 'https://cdn.imgbin.com/16/0/25/imgbin-active-directory-directory-service-computer-servers-windows-domain-computer-0MVUs58h9tPqF8nVb8RNxEi5w.jpg'
                }
            } -BundleImages
        }
        New-HTMLPanel {
            #$DomainControllers = Get-WinADForestControllers
            New-HTMLTable -DataTable $DomainControllers -HideFooter
        }
    }

} -ShowHTML
