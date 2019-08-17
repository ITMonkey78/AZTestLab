param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AzureRegion = 'West Europe',

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$CourseName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RequiredRdpVM
)

try {

    ## Download the Azure PowerShell module if the student doesn't have it
    if (-not (Get-Module -Name Azure -ListAvailable -ErrorAction Ignore)) {
        Install-Module -Name Azure -Force
    }

    ## If the student isn't already authenticated to Azure, ask them to
    if (-not (Get-AzContext)) {
        Connect-AzAccount
    }

    ## Hide the prog bar generated by Invoke-WebRequest
    $progPrefBefore = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    ## Download the ARM template
    $templatePath = "$env:TEMP\lab.json"
    $url = 'https://raw.githubusercontent.com/ITMonkey78/AZTestLab/master/lab.json'
    Invoke-WebRequest -Uri $url -OutFile $templatePath

    ## Azure resource group will be the course name
    $rgName = "$($CourseName -replace ' ','-')"

    ## Create the lab's resource group
    if (-not (Get-AzResourceGroup -Name $rgName -Location $AzureRegion -ErrorAction Ignore)) {
        $null = New-AzResourceGroup -Name $rgName -Location $AzureRegion
    }

    ## Deploy lab using the ARM template just downloaded
    $deploymentName = "$rgName-Deployment"
    $null = New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templatePath -Verbose

    $deploymentResult = (Get-AzResourceGroupDeployment -ResourceGroupName $rgName -Name $deploymentName).Outputs

    Write-Host "Your lab VM IPs to RDP to are:"
    $vmIps = @()
    foreach ($val in $deploymentResult.Values.Value) {
        $pubIp = Get-AzResource -ResourceId $val
        $vmName = $pubIp.Id.split('/')[-1].Replace('-pubip', '')
        $ip = (Get-AzPublicIpAddress -Name $pubip.Name).IpAddress
        $vmIps += [pscustomobject]@{
            Name = $vmName
            IP   = $ip
        }
        Write-Host "VM: $vmName IP: $ip"
    }

    ## If the student is on Windows, prompt and connect for them. Otherwise, tell them the IPs to connect to
    if ($env:OS -eq 'Windows_NT') {
        $rdpNow = Read-Host -Prompt "RDP to the required host ($RequiredRdpVM) now (Y,N)?"
        if ($rdpNow -eq 'Y') {
            $requiredVM = $vmIps.where({ $_.Name -eq $RequiredRdpVM })
            $ip = $requiredVM.IP
            mstsc /v:$ip
        } else {
            Write-Host "Please RDP to the VM [$($RequiredRdpVM) : $ip] now to begin testing."
        }
    } else {
        Write-Host "Please RDP to the VM [$($RequiredRdpVM) : $ip] now to begin testing."
    }
} catch {
    throw $_.Exception.Message
} finally {
    $ProgressPreference = $progPrefBefore
}
