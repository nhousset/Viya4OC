#!/bin/bash
# ==============================================================================
# Fichier : viya.sh
# Description : Orchestrateur d'administration SAS Viya 4 (Version Colorisée)
# ==============================================================================

# Définition des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
CMD_DIR="$SCRIPT_DIR/cmd"

# ==============================================================================
# 1. GESTION DE LA CONFIGURATION
# ==============================================================================

if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; fi

save_to_config() {
    local key=$1
    local value=$2
    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^export $key=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
    echo "export $key=\"$value\"" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

check_and_prompt_vars() {
    # 1. Demande de l'URL du Token en priorité absolue
    if [ -z "$TOKEN_URL" ]; then
        echo -e "${YELLOW}Initialisation de la configuration...${NC}"
        echo -e "Pour vous connecter au cluster, vous aurez besoin d'aller chercher un token sur l'interface web OpenShift."
        read -p "👉 URL pour récupérer le token OpenShift (ou 's' pour ignorer/skip) : " input_token_url
        if [ "$input_token_url" = "s" ] || [ "$input_token_url" = "S" ]; then
            TOKEN_URL="skip"
        else
            TOKEN_URL="$input_token_url"
        fi
        save_to_config "TOKEN_URL" "$TOKEN_URL"
    fi

    # 2. URL du cluster
    if [ -z "$SERVER_URL" ]; then
        read -p "👉 URL du cluster OpenShift : " SERVER_URL
        save_to_config "SERVER_URL" "$SERVER_URL"
    fi

    # 3. Demande du Token (avec affichage sympa de l'URL si dispo)
    if [ -z "$TOKEN" ]; then
        if [ -n "$TOKEN_URL" ] && [ "$TOKEN_URL" != "skip" ]; then
            echo -e "\n${PURPLE} ╭───────────────────────────────────────────────────────────${NC}"
            echo -e "${PURPLE} │ ${YELLOW}👋 Bonjour ! Il nous faut un jeton (token) OpenShift.${NC}"
            echo -e "${PURPLE} │ ${NC}Vous pouvez en générer un tout neuf en un clic via ce lien :${NC}"
            echo -e "${PURPLE} │ 🌐 ${BOLD}${CYAN}${TOKEN_URL}${NC}"
            echo -e "${PURPLE} ╰───────────────────────────────────────────────────────────${NC}\n"
        fi
        read -s -p "👉 Token de connexion OpenShift : " TOKEN
        echo ""
        save_to_config "TOKEN" "$TOKEN"
    fi

    # 4. Namespace et binaire oc
    if [ -z "$DEFAULT_NAMESPACE" ]; then
        read -p "👉 Namespace SAS Viya [sas-viya] : " input_ns
        DEFAULT_NAMESPACE=${input_ns:-sas-viya}
        save_to_config "DEFAULT_NAMESPACE" "$DEFAULT_NAMESPACE"
    fi
    if [ -z "$OC_BIN_PATH" ]; then
        read -p "👉 Chemin COMPLET du binaire oc : " OC_BIN_PATH
        save_to_config "OC_BIN_PATH" "$OC_BIN_PATH"
    fi
    
    if [ -n "$OC_BIN_PATH" ] && [ -f "$OC_BIN_PATH" ]; then
        export PATH="$(dirname "$OC_BIN_PATH"):$PATH"
    fi
    
    [ -z "$INSECURE_SKIP_TLS_VERIFY" ] && save_to_config "INSECURE_SKIP_TLS_VERIFY" "true"
    [ -z "$AUDIT_OUT_DIR" ] && save_to_config "AUDIT_OUT_DIR" "$SCRIPT_DIR/rapports_audit"
}

# ==============================================================================
# 2. LOGIQUE DE CONNEXION
# ==============================================================================

do_login() {
    check_and_prompt_vars
    local TLS_OPT=""
    [ "$INSECURE_SKIP_TLS_VERIFY" == "true" ] && TLS_OPT="--insecure-skip-tls-verify=true"

    if oc whoami >/dev/null 2>&1; then
        oc project "$DEFAULT_NAMESPACE" >/dev/null 2>&1
        return 0
    fi

    echo -e "${CYAN}🔌 Connexion à $SERVER_URL...${NC}"
    if oc login "$SERVER_URL" --token="$TOKEN" $TLS_OPT >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Connexion réussie.${NC}"
        oc project "$DEFAULT_NAMESPACE" >/dev/null 2>&1
    else
        echo -e "${RED}❌ Token invalide ou expiré.${NC}"
        
        # Affichage du rappel sympa d'URL si le token a expiré
        echo -e "\n${PURPLE} ╭───────────────────────────────────────────────────────────${NC}"
        echo -e "${PURPLE} │ ${YELLOW}💡 Oups ! Votre token est invalide ou a expiré.${NC}"
        if [ -n "$TOKEN_URL" ] && [ "$TOKEN_URL" != "skip" ]; then
            echo -e "${PURPLE} │ ${NC}Pas de panique, allez récupérer un nouveau token juste ici :${NC}"
            echo -e "${PURPLE} │ 🌐 ${BOLD}${CYAN}${TOKEN_URL}${NC}"
        else
            echo -e "${PURPLE} │ ${NC}Connectez-vous à l'interface web OpenShift pour en générer un nouveau.${NC}"
        fi
        echo -e "${PURPLE} ╰───────────────────────────────────────────────────────────${NC}\n"
        
        read -s -p "👉 Nouveau Token : " NEW_TOKEN ; echo ""
        [ -z "$NEW_TOKEN" ] && exit 1
        TOKEN="$NEW_TOKEN"
        save_to_config "TOKEN" "$TOKEN"
        if oc login "$SERVER_URL" --token="$TOKEN" $TLS_OPT >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Connexion réussie.${NC}"
            oc project "$DEFAULT_NAMESPACE" >/dev/null 2>&1
        else
            echo -e "${RED}❌ Échec critique.${NC}" ; exit 1
        fi
    fi
}

# ==============================================================================
# 3. AFFICHAGE DE L'AIDE
# ==============================================================================

show_help() {
    echo -e "${CYAN}"
    echo -e "  ____       _      ____   __     __  ___  __   __     _       _  _     ___   ____   ____  "
    echo -e " / ___|     / \    / ___|  \ \   / / |_ _| \ \ / /    / \     | || |   / _ \ |  _ \ / ___| "
    echo -e " \___ \    / _ \   \___ \   \ \ / /   | |   \ V /    / _ \    | || |_ | | | || |_) |\___ \ "
    echo -e "  ___) |  / ___ \   ___) |   \ V /    | |    | |    / ___ \   |__   _|| |_| ||  __/  ___) |"
    echo -e " |____/  /_/   \_\ |____/     \_/    |___|   |_|   /_/   \_\     |_|   \___/ |_|    |____/ "
    echo -e "${NC}"
    echo -e "${BOLD}${BLUE}============================================================================================${NC}"
    echo -e "${BOLD}   SAS VIYA 4 OPS - Aide & Utilisation${NC}"
    echo -e "   (c) Nicolas Housset | https://github.com/nhousset/Viya4OC/ | https://nicolas-housset.fr/"
    echo -e "${BOLD}${BLUE}============================================================================================${NC}"
    echo -e ""
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  ./viya.sh [OPTIONS]"
    echo -e ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${CYAN}-h, --help${NC}           Affiche cet écran d'aide."
    echo -e "  ${CYAN}--cmd <script.sh>${NC}    Exécute directement un script contenu dans le dossier 'cmd'"
    echo -e "                       sans passer par le menu interactif. L'authentification"
    echo -e "                       sera vérifiée avant le lancement."
    echo -e ""
    echo -e "${BOLD}Exemples:${NC}"
    echo -e "  ./viya.sh                        ${CYAN}# Lance le menu interactif${NC}"
    echo -e "  ./viya.sh --cmd check_status.sh  ${CYAN}# Exécute directement 'check_status.sh'${NC}"
    echo -e ""
}

# ==============================================================================
# 4. MENU DYNAMIQUE
# ==============================================================================

show_menu() {
    do_login 
    
    # Calcul du nombre de pods en cours d'exécution
    local RUNNING_COUNT=$(oc get pods -n "$DEFAULT_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    clear
    echo -e "${CYAN}"
    echo -e "  ____       _      ____   __     __  ___  __   __     _       _  _     ___   ____   ____  "
    echo -e " / ___|     / \    / ___|  \ \   / / |_ _| \ \ / /    / \     | || |   / _ \ |  _ \ / ___| "
    echo -e " \___ \    / _ \   \___ \   \ \ / /   | |   \ V /    / _ \    | || |_ | | | || |_) |\___ \ "
    echo -e "  ___) |  / ___ \   ___) |   \ V /    | |    | |    / ___ \   |__   _|| |_| ||  __/  ___) |"
    echo -e " |____/  /_/   \_\ |____/     \_/    |___|   |_|   /_/   \_\     |_|   \___/ |_|    |____/ "
    echo -e "${NC}"
    echo -e "${BLUE}============================================================================================${NC}"
    echo -e "${BOLD}   SAS VIYA 4 OPS - Console d'Administration${NC}"
    echo -e "   (c) Nicolas Housset | https://github.com/nhousset/Viya4OC/ | https://nicolas-housset.fr/"
    echo -e "${BLUE}============================================================================================${NC}"
    echo -e " Namespace : ${CYAN}$DEFAULT_NAMESPACE${NC}"
    echo -e " Statut    : ${GREEN}Connecté${NC} | ${YELLOW}Pods actifs: $RUNNING_COUNT${NC}"
    echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"

    if [ ! -d "$CMD_DIR" ]; then mkdir -p "$CMD_DIR"; fi

    local files=("$CMD_DIR"/*.sh)
    if [ ! -e "${files[0]}" ]; then
        echo -e "${RED}   (Aucun plugin trouvé)${NC}"
    else
        local i=1
        for f in "${files[@]}"; do
            local TITLE=$(grep "# TITLE:" "$f" | sed 's/# TITLE://' | sed 's/^[[:space:]]*//')
            [ -z "$TITLE" ] && TITLE=$(basename "$f")
            echo -e " ${BOLD}${CYAN}$i)${NC} $TITLE"
            ((i++))
        done
    fi

    echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
    echo -e " ${RED}q)${NC} Quitter & Logout      ${RED}x)${NC} Quitter (Garder session)"
    echo -e "${BLUE}============================================================================================${NC}"
    read -p "👉 Votre choix ? " CHOICE

    case "$CHOICE" in
        q) oc logout ; exit 0 ;;
        x) echo "Bye." ; exit 0 ;;
    esac

    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -ge $i ]; then
        echo -e "${RED}❌ Choix invalide.${NC}" ; sleep 1 ; show_menu ; return
    fi

    local SELECTED_SCRIPT="${files[$((CHOICE-1))]}"
    echo -e "\n${YELLOW}🚀 Lancement : $(basename "$SELECTED_SCRIPT")${NC}"
    echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
    
    chmod +x "$SELECTED_SCRIPT"
    export DEFAULT_NAMESPACE AUDIT_OUT_DIR
    
    "$SELECTED_SCRIPT"
    
    echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
    read -p "Appuyez sur Entrée pour revenir au menu..."
    show_menu
}

# ==============================================================================
# 5. GESTION DES ARGUMENTS ET LANCEMENT
# ==============================================================================

DIRECT_CMD=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --cmd)
            if [ -n "$2" ]; then
                DIRECT_CMD="$2"
                shift
            else
                echo -e "${RED}❌ Erreur : l'argument --cmd nécessite le nom d'un script.${NC}"
                echo -e "Utilisez --help pour plus d'informations."
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}❌ Option inconnue : $1${NC}"
            echo -e "Utilisez --help pour plus d'informations."
            exit 1
            ;;
    esac
    shift
done

# Lancement principal
if [ -n "$DIRECT_CMD" ]; then
    TARGET_SCRIPT="$CMD_DIR/$DIRECT_CMD"
    if [ ! -f "$TARGET_SCRIPT" ]; then
        echo -e "${RED}❌ Erreur : Le script '${DIRECT_CMD}' est introuvable dans le dossier '${CMD_DIR}'.${NC}"
        exit 1
    fi
    
    # Authentification requise même en mode direct
    do_login
    
    echo -e "\n${YELLOW}🚀 Lancement direct : ${DIRECT_CMD}${NC}"
    echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
    
    chmod +x "$TARGET_SCRIPT"
    export DEFAULT_NAMESPACE AUDIT_OUT_DIR
    
    "$TARGET_SCRIPT"
    exit $?
else
    # Lancement du menu par défaut
    show_menu
fi
