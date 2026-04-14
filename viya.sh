#!/bin/bash
# ==============================================================================
# Fichier : viya.sh
# Description : Orchestrateur d'administration SAS Viya 4
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
CMD_DIR="$SCRIPT_DIR/cmd"

# ==============================================================================
# 1. GESTION DE LA CONFIGURATION
# ==============================================================================

# Charge le fichier s'il existe
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Fonction pour ajouter ou mettre à jour une variable sans créer de doublon
save_to_config() {
    local key=$1
    local value=$2
    
    # Si le fichier existe, on supprime l'ancienne valeur
    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^export $key=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
    
    # On ajoute la nouvelle valeur
    echo "export $key=\"$value\"" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE" # Sécurité
}

# Vérifie les prérequis et demande ce qui manque
check_and_prompt_vars() {
    local updated=false

    if [ -z "$SERVER_URL" ]; then
        read -p "👉 URL du cluster OpenShift (ex: https://api.cluster:6443) : " SERVER_URL
        save_to_config "SERVER_URL" "$SERVER_URL"
    fi

    if [ -z "$TOKEN" ]; then
        read -s -p "👉 Token de connexion OpenShift : " TOKEN
        echo ""
        save_to_config "TOKEN" "$TOKEN"
    fi

    if [ -z "$DEFAULT_NAMESPACE" ]; then
        read -p "👉 Namespace SAS Viya [sas-viya par défaut] : " input_ns
        DEFAULT_NAMESPACE=${input_ns:-sas-viya}
        save_to_config "DEFAULT_NAMESPACE" "$DEFAULT_NAMESPACE"
    fi

    if [ -z "$OC_BIN_PATH" ]; then
        read -p "👉 Chemin COMPLET du binaire oc (ex: /usr/local/bin/oc ou C:/oc/oc.exe) : " OC_BIN_PATH
        save_to_config "OC_BIN_PATH" "$OC_BIN_PATH"
    fi
    
    # --- INJECTION DANS LE PATH ---
    # On extrait le dossier contenant le binaire oc et on le met au début du PATH
    if [ -n "$OC_BIN_PATH" ] && [ -f "$OC_BIN_PATH" ]; then
        export PATH="$(dirname "$OC_BIN_PATH"):$PATH"
    elif [ -n "$OC_BIN_PATH" ]; then
        echo "⚠️  Attention: le fichier $OC_BIN_PATH est introuvable. Assurez-vous que 'oc' est accessible."
    fi
    
    # Pour Viya, on ignore le TLS par défaut pour éviter les blocages de certificats internes
    if [ -z "$INSECURE_SKIP_TLS_VERIFY" ]; then
        INSECURE_SKIP_TLS_VERIFY="true"
        save_to_config "INSECURE_SKIP_TLS_VERIFY" "$INSECURE_SKIP_TLS_VERIFY"
    fi
    
    # Dossier d'export par défaut
    if [ -z "$AUDIT_OUT_DIR" ]; then
        AUDIT_OUT_DIR="$SCRIPT_DIR/rapports_audit"
        save_to_config "AUDIT_OUT_DIR" "$AUDIT_OUT_DIR"
    fi
}

# ==============================================================================
# 2. LOGIQUE DE CONNEXION (Avec retry unique)
# ==============================================================================

do_login() {
    # 1. On s'assure d'avoir toutes les infos
    check_and_prompt_vars

    local TLS_OPT=""
    if [ "$INSECURE_SKIP_TLS_VERIFY" == "true" ]; then
        TLS_OPT="--insecure-skip-tls-verify=true"
    fi

    # 2. Vérification rapide : est-on déjà connecté avec un token valide ?
    if oc whoami >/dev/null 2>&1; then
        oc project "$DEFAULT_NAMESPACE" >/dev/null 2>&1
        return 0
    fi

    # 3. Première tentative de connexion
    echo "🔌 Tentative de connexion à $SERVER_URL..."
    if oc login "$SERVER_URL" --token="$TOKEN" $TLS_OPT >/dev/null 2>&1; then
        echo "✅ Connexion réussie."
        oc project "$DEFAULT_NAMESPACE" >/dev/null 2>&1
    else
        # 4. Échec -> On demande UNE FOIS de resaisir le token
        echo "❌ Échec de la connexion (Le Token est expiré ou invalide)."
        read -s -p "👉 Veuillez resaisir un nouveau Token : " NEW_TOKEN
        echo ""
        
        if [ -z "$NEW_TOKEN" ]; then 
            echo "Annulation."
            exit 1
        fi
        
        TOKEN="$NEW_TOKEN"
        save_to_config "TOKEN" "$TOKEN"

        echo "🔌 Nouvelle tentative..."
        if oc login "$SERVER_URL" --token="$TOKEN" $TLS_OPT >/dev/null 2>&1; then
            echo "✅ Connexion réussie."
            oc project "$DEFAULT_NAMESPACE" >/dev/null 2>&1
        else
            echo "❌ Échec critique de la connexion. Fin du script."
            exit 1
        fi
    fi
}

do_logout() {
    echo "👋 Déconnexion d'OpenShift..."
    oc logout
}

# ==============================================================================
# 3. MOTEUR DE PLUGINS ET MENU
# ==============================================================================

show_menu() {
    # On garantit la connexion avant d'afficher le menu
    do_login 
    
    clear
    echo "=========================================="
    echo "   MENU VIYA 4 OPS  (Namespace: $DEFAULT_NAMESPACE)"
    echo "=========================================="

    if [ ! -d "$CMD_DIR" ]; then
        mkdir -p "$CMD_DIR"
        echo "📂 Création du dossier $CMD_DIR..."
    fi

    local files=("$CMD_DIR"/*.sh)
    # Vérification si le dossier est vide
    if [ ! -e "${files[0]}" ]; then
        echo "   (Aucun plugin trouvé dans $CMD_DIR/)"
        echo "=========================================="
        echo " q) Quitter & Logout"
        echo " x) Quitter (Garder session)"
        read -p "Votre choix ? " CHOICE
    else
        local i=1
        for f in "${files[@]}"; do
            local TITLE=$(grep "# TITLE:" "$f" | sed 's/# TITLE://' | sed 's/^[[:space:]]*//')
            if [ -z "$TITLE" ]; then TITLE=$(basename "$f"); fi
            echo " $i) $TITLE"
            ((i++))
        done
        echo "------------------------------------------"
        echo " q) Quitter & Logout"
        echo " x) Quitter (Garder session)"
        echo "=========================================="
        read -p "Votre choix ? " CHOICE
    fi

    if [[ "$CHOICE" == "q" ]]; then
        do_logout
        exit 0
    elif [[ "$CHOICE" == "x" ]]; then
        echo "Fermeture du menu. Session conservée."
        exit 0
    fi

    # Validation du choix numérique
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -ge $i ]; then
        echo "❌ Choix invalide."
        sleep 1
        show_menu
        return
    fi

    local SELECTED_SCRIPT="${files[$((CHOICE-1))]}"
    
    echo ""
    echo "🚀 Lancement de : $(basename "$SELECTED_SCRIPT")"
    echo "------------------------------------------"
    
    chmod +x "$SELECTED_SCRIPT"
    
    # Exporte les variables utiles pour les sous-scripts
    export DEFAULT_NAMESPACE
    export AUDIT_OUT_DIR
    
    # Exécution du plugin
    "$SELECTED_SCRIPT"
    
    echo "------------------------------------------"
    read -p "Appuyez sur Entrée pour revenir au menu..."
    show_menu
}

# ==============================================================================
# MAIN
# ==============================================================================

case "$1" in
    login)  do_login ;;
    logout) do_logout ;;
    *)      show_menu ;;
esac
