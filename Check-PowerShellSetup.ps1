#Requires -Version 7.0
<#
.SYNOPSIS
    Verifica e instala módulos PowerShell para M365/Azure no macOS
.DESCRIPTION
    Script para verificar instalação do PowerShell e módulos necessários
    para administração de Microsoft 365, Azure, Exchange, Teams e SharePoint
.AUTHOR
    Nassif - IT Admin
.DATE
    Janeiro 2025
.EXAMPLE
    ./Check-PowerShellSetup.ps1
    ./Check-PowerShellSetup.ps1 -InstallMissing
    ./Check-PowerShellSetup.ps1 -UpdateAll
#>

[CmdletBinding()]
param(
    [switch]$InstallMissing,
    [switch]$UpdateAll,
    [switch]$ShowConnections
)

#===============================================================================
# CONFIGURAÇÃO
#===============================================================================
$RequiredModules = @(
    @{ Name = "Az"; Description = "Azure PowerShell" }
    @{ Name = "Microsoft.Graph"; Description = "Microsoft Graph API" }
    @{ Name = "ExchangeOnlineManagement"; Description = "Exchange Online" }
    @{ Name = "MicrosoftTeams"; Description = "Microsoft Teams" }
    @{ Name = "Microsoft.Online.SharePoint.PowerShell"; Description = "SharePoint Online" }
)

#===============================================================================
# FUNÇÕES DE OUTPUT
#===============================================================================
function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

#===============================================================================
# VERIFICAÇÃO DO SISTEMA
#===============================================================================
function Get-SystemInfo {
    Write-Header "Informações do Sistema"
    
    $osInfo = if ($IsMacOS) {
        $macVersion = sw_vers -productVersion
        "macOS $macVersion"
    } elseif ($IsWindows) {
        [System.Environment]::OSVersion.VersionString
    } else {
        "Linux"
    }
    
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    
    Write-Host "  Sistema:     $osInfo"
    Write-Host "  Arquitetura: $arch"
    Write-Host "  PowerShell:  $($PSVersionTable.PSVersion)"
    Write-Host "  PSEdition:   $($PSVersionTable.PSEdition)"
    Write-Host "  Host:        $($Host.Name)"
}

#===============================================================================
# VERIFICAÇÃO DOS MÓDULOS
#===============================================================================
function Get-ModuleStatus {
    Write-Header "Status dos Módulos"
    
    $results = @()
    
    foreach ($module in $RequiredModules) {
        $installed = Get-InstalledModule -Name $module.Name -ErrorAction SilentlyContinue
        $available = Find-Module -Name $module.Name -ErrorAction SilentlyContinue | Select-Object -First 1
        
        $status = [PSCustomObject]@{
            Name            = $module.Name
            Description     = $module.Description
            Installed       = $null -ne $installed
            InstalledVersion = if ($installed) { $installed.Version.ToString() } else { "N/A" }
            LatestVersion   = if ($available) { $available.Version.ToString() } else { "N/A" }
            NeedsUpdate     = $false
        }
        
        if ($installed -and $available) {
            $status.NeedsUpdate = [version]$available.Version -gt [version]$installed.Version
        }
        
        # Output formatado
        if ($status.Installed) {
            if ($status.NeedsUpdate) {
                Write-Warning "$($status.Name): v$($status.InstalledVersion) → v$($status.LatestVersion) disponível"
            } else {
                Write-Success "$($status.Name): v$($status.InstalledVersion)"
            }
        } else {
            Write-Warning "$($status.Name): Não instalado (v$($status.LatestVersion) disponível)"
        }
        
        $results += $status
    }
    
    return $results
}

#===============================================================================
# INSTALAÇÃO DOS MÓDULOS
#===============================================================================
function Install-MissingModules {
    param([array]$ModuleStatus)
    
    Write-Header "Instalando Módulos Faltantes"
    
    $missing = $ModuleStatus | Where-Object { -not $_.Installed }
    
    if ($missing.Count -eq 0) {
        Write-Success "Todos os módulos já estão instalados!"
        return
    }
    
    foreach ($module in $missing) {
        Write-Info "Instalando $($module.Name)..."
        try {
            Install-Module -Name $module.Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Success "$($module.Name) instalado com sucesso"
        }
        catch {
            Write-Error "Falha ao instalar $($module.Name): $_"
        }
    }
}

#===============================================================================
# ATUALIZAÇÃO DOS MÓDULOS
#===============================================================================
function Update-AllModules {
    param([array]$ModuleStatus)
    
    Write-Header "Atualizando Módulos"
    
    $outdated = $ModuleStatus | Where-Object { $_.Installed -and $_.NeedsUpdate }
    
    if ($outdated.Count -eq 0) {
        Write-Success "Todos os módulos estão atualizados!"
        return
    }
    
    foreach ($module in $outdated) {
        Write-Info "Atualizando $($module.Name) de v$($module.InstalledVersion) para v$($module.LatestVersion)..."
        try {
            Update-Module -Name $module.Name -Force -ErrorAction Stop
            Write-Success "$($module.Name) atualizado com sucesso"
        }
        catch {
            Write-Error "Falha ao atualizar $($module.Name): $_"
        }
    }
}

#===============================================================================
# VERIFICAÇÃO DO PERFIL
#===============================================================================
function Get-ProfileStatus {
    Write-Header "Perfil do PowerShell"
    
    Write-Host "  Caminho: $PROFILE"
    
    if (Test-Path $PROFILE) {
        Write-Success "Perfil existe"
        
        $content = Get-Content $PROFILE -Raw
        if ($content -match "Import-Module MicrosoftTeams") {
            Write-Success "Import do MicrosoftTeams configurado"
        } else {
            Write-Warning "Import do MicrosoftTeams não encontrado no perfil"
            
            $response = Read-Host "Deseja adicionar? (s/n)"
            if ($response -eq 's') {
                Add-Content -Path $PROFILE -Value "`nImport-Module MicrosoftTeams"
                Write-Success "Adicionado ao perfil"
            }
        }
    } else {
        Write-Warning "Perfil não existe"
        
        $response = Read-Host "Deseja criar o perfil? (s/n)"
        if ($response -eq 's') {
            $profileDir = Split-Path $PROFILE -Parent
            if (-not (Test-Path $profileDir)) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }
            
            $profileContent = @"
# PowerShell Profile
# Criado em $(Get-Date -Format "yyyy-MM-dd")

# Auto-import de módulos necessários
Import-Module MicrosoftTeams

# Aliases úteis (opcional)
# Set-Alias -Name exo -Value Connect-ExchangeOnline
# Set-Alias -Name graph -Value Connect-MgGraph
"@
            Set-Content -Path $PROFILE -Value $profileContent
            Write-Success "Perfil criado: $PROFILE"
        }
    }
}

#===============================================================================
# COMANDOS DE CONEXÃO
#===============================================================================
function Show-ConnectionCommands {
    Write-Header "Comandos de Conexão"
    
    $connections = @"

  # Microsoft Graph (substitui AzureAD e MSOnline)
  Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","Directory.Read.All"

  # Azure
  Connect-AzAccount

  # Exchange Online
  Connect-ExchangeOnline -UserPrincipalName admin@seutenant.onmicrosoft.com

  # Microsoft Teams
  Import-Module MicrosoftTeams
  Connect-MicrosoftTeams

  # SharePoint Online
  Connect-SPOService -Url https://SEUTENANT-admin.sharepoint.com

  # Security & Compliance (Purview)
  Connect-IPPSSession -UserPrincipalName admin@seutenant.onmicrosoft.com

  # Desconectar de todos
  Disconnect-MgGraph
  Disconnect-AzAccount
  Disconnect-ExchangeOnline -Confirm:`$false
  Disconnect-MicrosoftTeams
  Disconnect-SPOService

"@
    
    Write-Host $connections -ForegroundColor Gray
}

#===============================================================================
# RELATÓRIO FINAL
#===============================================================================
function Show-Report {
    param([array]$ModuleStatus)
    
    Write-Header "Resumo"
    
    $installed = ($ModuleStatus | Where-Object { $_.Installed }).Count
    $missing = ($ModuleStatus | Where-Object { -not $_.Installed }).Count
    $outdated = ($ModuleStatus | Where-Object { $_.Installed -and $_.NeedsUpdate }).Count
    
    Write-Host ""
    Write-Host "  Módulos instalados:   " -NoNewline
    Write-Host $installed -ForegroundColor Green
    
    Write-Host "  Módulos faltando:     " -NoNewline
    if ($missing -gt 0) {
        Write-Host $missing -ForegroundColor Yellow
    } else {
        Write-Host $missing -ForegroundColor Green
    }
    
    Write-Host "  Módulos desatualizados: " -NoNewline
    if ($outdated -gt 0) {
        Write-Host $outdated -ForegroundColor Yellow
    } else {
        Write-Host $outdated -ForegroundColor Green
    }
    
    Write-Host ""
    
    if ($missing -gt 0) {
        Write-Info "Execute com -InstallMissing para instalar módulos faltantes"
    }
    if ($outdated -gt 0) {
        Write-Info "Execute com -UpdateAll para atualizar módulos"
    }
}

#===============================================================================
# MAIN
#===============================================================================
function Main {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║    PowerShell M365/Azure - Verificação de Ambiente         ║" -ForegroundColor Cyan
    Write-Host "║                     v1.0 - 2025                            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Info do sistema
    Get-SystemInfo
    
    # Status dos módulos
    $status = Get-ModuleStatus
    
    # Instalar faltantes se solicitado
    if ($InstallMissing) {
        Install-MissingModules -ModuleStatus $status
        $status = Get-ModuleStatus  # Refresh
    }
    
    # Atualizar se solicitado
    if ($UpdateAll) {
        Update-AllModules -ModuleStatus $status
        $status = Get-ModuleStatus  # Refresh
    }
    
    # Verificar perfil
    Get-ProfileStatus
    
    # Mostrar comandos de conexão
    if ($ShowConnections) {
        Show-ConnectionCommands
    }
    
    # Relatório final
    Show-Report -ModuleStatus $status
    
    Write-Host ""
}

# Executar
Main
