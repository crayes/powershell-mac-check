#!/bin/bash
#===============================================================================
# Script: setup-powershell-mac.sh
# Descrição: Verifica e instala PowerShell + módulos M365/Azure no macOS
# Autor: Nassif - IT Admin
# Data: Janeiro 2025
# Uso: chmod +x setup-powershell-mac.sh && ./setup-powershell-mac.sh
#===============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Módulos necessários
MODULES=(
    "Az"
    "Microsoft.Graph"
    "ExchangeOnlineManagement"
    "MicrosoftTeams"
    "Microsoft.Online.SharePoint.PowerShell"
)

# Funções de output
print_header() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

#===============================================================================
# VERIFICAÇÃO DO HOMEBREW
#===============================================================================
check_homebrew() {
    print_header "Verificando Homebrew"
    
    if command -v brew &> /dev/null; then
        BREW_VERSION=$(brew --version | head -n 1)
        print_success "Homebrew instalado: $BREW_VERSION"
        return 0
    else
        print_warning "Homebrew não encontrado"
        read -p "Deseja instalar o Homebrew? (s/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            print_info "Instalando Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Adicionar ao PATH (Apple Silicon)
            if [[ $(uname -m) == "arm64" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            print_success "Homebrew instalado com sucesso"
        else
            print_error "Homebrew é necessário. Abortando."
            exit 1
        fi
    fi
}

#===============================================================================
# VERIFICAÇÃO DO POWERSHELL
#===============================================================================
check_powershell() {
    print_header "Verificando PowerShell"
    
    if command -v pwsh &> /dev/null; then
        PWSH_VERSION=$(pwsh --version)
        print_success "PowerShell instalado: $PWSH_VERSION"
        
        # Verificar se há atualização disponível
        print_info "Verificando atualizações..."
        brew update > /dev/null 2>&1
        
        OUTDATED=$(brew outdated --cask 2>/dev/null | grep -i powershell || true)
        if [[ -n "$OUTDATED" ]]; then
            print_warning "Atualização disponível para PowerShell"
            read -p "Deseja atualizar? (s/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                brew upgrade --cask powershell
                print_success "PowerShell atualizado"
            fi
        else
            print_success "PowerShell está na versão mais recente"
        fi
        return 0
    else
        print_warning "PowerShell não encontrado"
        install_powershell
    fi
}

install_powershell() {
    read -p "Deseja instalar o PowerShell? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_info "Instalando PowerShell via Homebrew Cask..."
        brew install --cask powershell
        
        if command -v pwsh &> /dev/null; then
            PWSH_VERSION=$(pwsh --version)
            print_success "PowerShell instalado: $PWSH_VERSION"
        else
            print_error "Falha na instalação do PowerShell"
            exit 1
        fi
    else
        print_error "PowerShell é necessário. Abortando."
        exit 1
    fi
}

#===============================================================================
# VERIFICAÇÃO DOS MÓDULOS
#===============================================================================
check_modules() {
    print_header "Verificando Módulos PowerShell"
    
    MISSING_MODULES=()
    OUTDATED_MODULES=()
    INSTALLED_MODULES=()
    
    for MODULE in "${MODULES[@]}"; do
        # Verificar se o módulo está instalado e obter versões
        RESULT=$(pwsh -NoProfile -Command "
            \$installed = Get-InstalledModule -Name '$MODULE' -ErrorAction SilentlyContinue
            \$available = Find-Module -Name '$MODULE' -ErrorAction SilentlyContinue | Select-Object -First 1
            if (\$installed) {
                \$needsUpdate = \$false
                if (\$available -and ([version]\$available.Version -gt [version]\$installed.Version)) {
                    \$needsUpdate = \$true
                }
                Write-Output \"INSTALLED|\$(\$installed.Version)|\$(\$available.Version)|\$needsUpdate\"
            } else {
                Write-Output \"MISSING|N/A|\$(\$available.Version)|false\"
            }
        " 2>/dev/null || echo "ERROR|N/A|N/A|false")
        
        STATUS=$(echo "$RESULT" | cut -d'|' -f1)
        INSTALLED_VER=$(echo "$RESULT" | cut -d'|' -f2)
        LATEST_VER=$(echo "$RESULT" | cut -d'|' -f3)
        NEEDS_UPDATE=$(echo "$RESULT" | cut -d'|' -f4)
        
        if [[ "$STATUS" == "INSTALLED" ]]; then
            if [[ "$NEEDS_UPDATE" == "True" ]]; then
                print_warning "$MODULE: v$INSTALLED_VER → v$LATEST_VER disponível"
                OUTDATED_MODULES+=("$MODULE")
            else
                print_success "$MODULE: v$INSTALLED_VER (atualizado)"
                INSTALLED_MODULES+=("$MODULE")
            fi
        else
            print_warning "$MODULE: Não instalado (v$LATEST_VER disponível)"
            MISSING_MODULES+=("$MODULE")
        fi
    done
    
    echo ""
    echo -e "${BLUE}Resumo:${NC}"
    echo -e "  Instalados e atualizados: ${GREEN}${#INSTALLED_MODULES[@]}${NC}"
    echo -e "  Desatualizados:           ${YELLOW}${#OUTDATED_MODULES[@]}${NC}"
    echo -e "  Faltando:                 ${YELLOW}${#MISSING_MODULES[@]}${NC}"
    
    # Atualizar módulos desatualizados
    if [[ ${#OUTDATED_MODULES[@]} -gt 0 ]]; then
        echo ""
        read -p "Deseja atualizar os módulos desatualizados? (s/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            update_modules "${OUTDATED_MODULES[@]}"
        fi
    fi
    
    # Instalar módulos faltantes
    if [[ ${#MISSING_MODULES[@]} -gt 0 ]]; then
        echo ""
        read -p "Deseja instalar os módulos faltantes? (s/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_modules "${MISSING_MODULES[@]}"
        fi
    fi
}

install_modules() {
    local MODULES_TO_INSTALL=("$@")
    
    print_header "Instalando Módulos"
    
    for MODULE in "${MODULES_TO_INSTALL[@]}"; do
        print_info "Instalando $MODULE..."
        
        pwsh -NoProfile -Command "
            \$ProgressPreference = 'SilentlyContinue'
            Install-Module -Name '$MODULE' -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        " 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            print_success "$MODULE instalado"
        else
            print_error "Falha ao instalar $MODULE"
        fi
    done
}

update_modules() {
    local MODULES_TO_UPDATE=("$@")
    
    print_header "Atualizando Módulos (removendo versão antiga)"
    
    for MODULE in "${MODULES_TO_UPDATE[@]}"; do
        print_info "Removendo versão antiga de $MODULE..."
        
        # Remover todas as versões antigas
        pwsh -NoProfile -Command "
            \$ProgressPreference = 'SilentlyContinue'
            Get-InstalledModule -Name '$MODULE' -AllVersions -ErrorAction SilentlyContinue | 
                Uninstall-Module -Force -ErrorAction SilentlyContinue
        " 2>/dev/null
        
        print_info "Instalando versão mais recente de $MODULE..."
        
        # Instalar versão mais recente
        pwsh -NoProfile -Command "
            \$ProgressPreference = 'SilentlyContinue'
            Install-Module -Name '$MODULE' -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        " 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            NEW_VER=$(pwsh -NoProfile -Command "Get-InstalledModule -Name '$MODULE' | Select-Object -ExpandProperty Version" 2>/dev/null)
            print_success "$MODULE atualizado para v$NEW_VER"
        else
            print_error "Falha ao atualizar $MODULE"
        fi
    done
}

#===============================================================================
# VERIFICAÇÃO DO PERFIL DO POWERSHELL
#===============================================================================
check_profile() {
    print_header "Verificando Perfil do PowerShell"
    
    PROFILE_PATH=$(pwsh -NoProfile -Command 'Write-Output $PROFILE' 2>/dev/null)
    
    if [[ -f "$PROFILE_PATH" ]]; then
        print_success "Perfil existe: $PROFILE_PATH"
        
        # Verificar se MicrosoftTeams está no perfil
        if grep -q "Import-Module MicrosoftTeams" "$PROFILE_PATH" 2>/dev/null; then
            print_success "Import do MicrosoftTeams já está no perfil"
        else
            read -p "Deseja adicionar 'Import-Module MicrosoftTeams' ao perfil? (s/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                echo "Import-Module MicrosoftTeams" >> "$PROFILE_PATH"
                print_success "Adicionado ao perfil"
            fi
        fi
    else
        print_warning "Perfil não existe"
        read -p "Deseja criar o perfil com Import-Module MicrosoftTeams? (s/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            mkdir -p "$(dirname "$PROFILE_PATH")"
            echo "# PowerShell Profile" > "$PROFILE_PATH"
            echo "Import-Module MicrosoftTeams" >> "$PROFILE_PATH"
            print_success "Perfil criado: $PROFILE_PATH"
        fi
    fi
}

#===============================================================================
# LIMPEZA DO HOMEBREW
#===============================================================================
cleanup_homebrew() {
    print_header "Limpeza do Homebrew"
    
    # Verificar espaço do cache
    CACHE_SIZE=$(du -sh "$(brew --cache)" 2>/dev/null | cut -f1)
    print_info "Cache do Homebrew: $CACHE_SIZE"
    
    read -p "Deseja limpar o cache do Homebrew? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_info "Executando limpeza..."
        brew autoremove
        brew cleanup --prune=all
        rm -rf "$(brew --cache)" 2>/dev/null || true
        print_success "Limpeza concluída"
    fi
}

#===============================================================================
# RELATÓRIO FINAL
#===============================================================================
print_report() {
    print_header "Relatório Final"
    
    echo ""
    echo -e "${BLUE}Sistema:${NC}"
    echo "  macOS: $(sw_vers -productVersion)"
    echo "  Arch:  $(uname -m)"
    echo ""
    
    echo -e "${BLUE}PowerShell:${NC}"
    if command -v pwsh &> /dev/null; then
        echo "  Versão: $(pwsh --version)"
        echo "  Path:   $(which pwsh)"
    else
        echo "  Status: Não instalado"
    fi
    echo ""
    
    echo -e "${BLUE}Módulos Instalados:${NC}"
    pwsh -NoProfile -Command "
        \$modules = @('Az', 'Microsoft.Graph', 'ExchangeOnlineManagement', 'MicrosoftTeams', 'Microsoft.Online.SharePoint.PowerShell')
        foreach (\$mod in \$modules) {
            \$installed = Get-InstalledModule -Name \$mod -ErrorAction SilentlyContinue
            if (\$installed) {
                Write-Host \"  \$mod : v\$(\$installed.Version)\" -ForegroundColor Green
            } else {
                Write-Host \"  \$mod : Não instalado\" -ForegroundColor Yellow
            }
        }
    " 2>/dev/null
    
    echo ""
    echo -e "${BLUE}Comandos de Conexão:${NC}"
    echo "  Connect-MgGraph -Scopes \"User.Read.All\""
    echo "  Connect-AzAccount"
    echo "  Connect-ExchangeOnline"
    echo "  Connect-MicrosoftTeams"
    echo "  Connect-SPOService -Url https://TENANT-admin.sharepoint.com"
    echo ""
}

#===============================================================================
# MENU PRINCIPAL
#===============================================================================
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     PowerShell + M365/Azure Setup Script para macOS       ║"
    echo "║                      v1.1 - 2025                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "1) Executar verificação completa (recomendado)"
    echo "2) Verificar apenas Homebrew"
    echo "3) Verificar apenas PowerShell"
    echo "4) Verificar apenas Módulos"
    echo "5) Verificar/Criar Perfil PowerShell"
    echo "6) Limpar cache do Homebrew"
    echo "7) Exibir relatório"
    echo "8) Sair"
    echo ""
    read -p "Selecione uma opção: " -n 1 -r
    echo
}

run_full_check() {
    check_homebrew
    check_powershell
    check_modules
    check_profile
    print_report
}

#===============================================================================
# MAIN
#===============================================================================
main() {
    # Se executado com --auto, roda verificação completa sem menu
    if [[ "$1" == "--auto" ]]; then
        run_full_check
        exit 0
    fi
    
    # Menu interativo
    while true; do
        show_menu
        case $REPLY in
            1) run_full_check; read -p "Pressione Enter para continuar..." ;;
            2) check_homebrew; read -p "Pressione Enter para continuar..." ;;
            3) check_powershell; read -p "Pressione Enter para continuar..." ;;
            4) check_modules; read -p "Pressione Enter para continuar..." ;;
            5) check_profile; read -p "Pressione Enter para continuar..." ;;
            6) cleanup_homebrew; read -p "Pressione Enter para continuar..." ;;
            7) print_report; read -p "Pressione Enter para continuar..." ;;
            8) echo "Saindo..."; exit 0 ;;
            *) print_error "Opção inválida" ;;
        esac
    done
}

# Executar
main "$@"
