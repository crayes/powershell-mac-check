# PowerShell MAC Check

Scripts para verificar e instalar PowerShell + módulos M365/Azure no macOS.

## 📋 Módulos Incluídos

| Módulo | Descrição |
|--------|------------|
| Az | Azure PowerShell |
| Microsoft.Graph | Microsoft Graph API (Entra ID / M365) |
| ExchangeOnlineManagement | Exchange Online + Purview |
| MicrosoftTeams | Microsoft Teams |
| Microsoft.Online.SharePoint.PowerShell | SharePoint Online |

## 🚀 Scripts Disponíveis

### 1. setup-powershell-mac.sh (Bash)

Script completo para Macs que **ainda não têm PowerShell** instalado. Menu interativo que:

- ✅ Verifica/instala Homebrew
- ✅ Verifica/instala PowerShell
- ✅ Verifica/instala os módulos
- ✅ **Remove versões antigas e instala a mais recente automaticamente**
- ✅ Configura o perfil do PowerShell
- ✅ Limpa cache do Homebrew

**Como usar:**

```bash
# Dar permissão de execução
chmod +x setup-powershell-mac.sh

# Executar (menu interativo)
./setup-powershell-mac.sh

# Ou execução automática sem menu
./setup-powershell-mac.sh --auto
```

### 2. Check-PowerShellSetup.ps1 (PowerShell)

Script para Macs que **já têm PowerShell** instalado. Verifica e atualiza módulos.

**Comportamento de atualização:** Quando encontra módulos desatualizados, o script **remove a versão antiga** e **instala a versão mais recente** automaticamente.

**Como usar:**

```powershell
# Apenas verificar status
./Check-PowerShellSetup.ps1

# Corrigir TUDO automaticamente (instala faltantes + atualiza desatualizados)
./Check-PowerShellSetup.ps1 -AutoFix

# Instalar apenas módulos faltantes
./Check-PowerShellSetup.ps1 -InstallMissing

# Atualizar apenas módulos desatualizados (remove antigo + instala novo)
./Check-PowerShellSetup.ps1 -UpdateAll

# Mostrar comandos de conexão
./Check-PowerShellSetup.ps1 -ShowConnections
```

## 📡 Comandos de Conexão Rápida

```powershell
# Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All","Group.Read.All"

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
```

## 🔧 Requisitos

- macOS 10.15 (Catalina) ou superior
- Homebrew (instalado automaticamente se necessário)
- PowerShell 7.x
- Conexão com internet

## 📝 Notas

- O módulo `MicrosoftTeams` precisa ser importado manualmente antes de usar. O script pode configurar isso automaticamente no perfil do PowerShell.
- Os scripts usam `Scope CurrentUser` para não requerer privilégios de admin.
- O script Bash pode instalar tudo do zero em um Mac limpo.
- **Módulos desatualizados são removidos e reinstalados** para evitar conflitos de versão.

## 📄 Changelog

### v1.1 (Janeiro 2025)
- Adicionado: Remoção automática de versões antigas antes de instalar nova versão
- Adicionado: Parâmetro `-AutoFix` no script PowerShell para corrigir tudo automaticamente
- Melhorado: Detecção de módulos desatualizados

### v1.0 (Janeiro 2025)
- Release inicial

## 📄 Licença

MIT License

---

**Autor:** Nassif - IT Admin  
**Data:** Janeiro 2025
