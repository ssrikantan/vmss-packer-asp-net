

$rootdir = (Resolve-Path .\).Path
Write-Output "current directory is  $rootdir."

# --------------------------------------------------------------------
# Define the variables.
# --------------------------------------------------------------------
$InetPubRoot = "C:\Inetpub"
$InetPubLog = "C:\Inetpub\Logs"
$InetPubWWWRoot = "C:\Inetpub\WWWRoot"

# --------------------------------------------------------------------
# Loading Feature Installation Modules
# --------------------------------------------------------------------
$Command = "icacls ..\ /grant ""Network Service"":(OI)(CI)W"
cmd.exe /c $Command
Write-Output "Granted network service access ..."

#Write-Output "Runbook started from webhook $WebhookName by $From."

# --------------------------------------------------------------------
# Loading IIS Modules
# --------------------------------------------------------------------
Import-Module ServerManager 

# --------------------------------------------------------------------
# Installing IIS
# --------------------------------------------------------------------
$features = @(
   "Web-WebServer",
   "Web-Static-Content",
   "Web-Http-Errors",
   "Web-Http-Redirect",
   "Web-Stat-Compression",
   "Web-Filtering",
   "Web-Asp-Net45",
   "Web-Net-Ext45",
   "Web-ISAPI-Ext",
   "Web-ISAPI-Filter",
   "Web-Mgmt-Console",
   "Web-Mgmt-Service",
   "Web-Mgmt-Tools",
   "NET-Framework-45-ASPNET"
)
Add-WindowsFeature $features -Verbose

Write-Output "Added all the Windows Features ..."
## --------------------------------------------------------------------
## Loading IIS Modules
## --------------------------------------------------------------------
Import-Module WebAdministration

## --------------------------------------------------------------------
## Setting directory access
## --------------------------------------------------------------------
$Command = "icacls $InetPubWWWRoot /grant BUILTIN\IIS_IUSRS:(OI)(CI)(RX) BUILTIN\Users:(OI)(CI)(RX)"
cmd.exe /c $Command
$Command = "icacls $InetPubLog /grant ""NT SERVICE\TrustedInstaller"":(OI)(CI)(F)"
cmd.exe /c $Command

Write-Output "Set directory access ..."

## --------------------------------------------------------------------
## Resetting IIS
## --------------------------------------------------------------------
$Command = "IISRESET"
Invoke-Expression -Command $Command

Write-Output "IIS Reset completed ..."
$source = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
$dest = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
Try
{
	Invoke-WebRequest $source -OutFile $dest
}
Catch
{
    Write-Output "Error downloading Web Deploy exe ..." | Write-Output
}
Write-Output "Web Deploy exe downloaded ..."

cd "C:\WindowsAzure"

Try
{
    Start-Process msiexec -ArgumentList "/package WebDeploy_amd64_en-US.msi /qn /norestart ADDLOCAL=ALL  LicenseAccepted='0'" -Wait
}
Catch
{
    Write-Output "Error installing Webdeloy exe ..." | Write-Output
}

Write-Output "Web Deploy exe installed ..."

$MSDeployPath = (Get-ChildItem "HKLM:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy" | Select -Last 1).GetValue("InstallPath")
$MSdeploycommand = $MSDeployPath + "msdeploy.exe"
Write-Output "Web deploy is installed here ...$MSDeployPath"

Write-Output "Deploying the Web App package..."
 #important - The path C:\DeployTemp\drop is where the 'Build Immutable Image' Packer Task in the CD Pipeline would
 # copy the Web Application Package to. Hence that path has been hardcoded here
 Try
 {

$msdeployArguments = '-verb:sync',

       '-source:package="C:\DeployTemp\drop\simple2tierweb.zip"',

       '-dest:auto,ComputerName="localhost"',

       '-allowUntrusted'



& $MSDeployPath\msdeploy.exe $msdeployArguments
}
Catch
{
    Write-Output "Error deploying the web package" | Write-Output
}


Write-Output "The Web package has been deployed"

