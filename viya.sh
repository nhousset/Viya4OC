#!/bin/bash
# ==============================================================================
# Fichier : viya.sh
# Description : Menu principal et orchestrateur pour l'administration SAS Viya 4
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
CMD_DIR="$SCRIPT_DIR/cmd"

# --- Création de la config si elle n'existe pas ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Création du fichier $CONFIG_FILE..."
    cat <<EOF > "$CONFIG_FILE"
export SERVER_URL=""
export TOKEN=""
export DEFAULT_NAMESPACE="sas-viya"
export INSECURE_SKIP_TLS_VERIFY="false"
export AUDIT_OUT_DIR="./rapports_audit"
EOF
    chmod 600 "$CONFIG_FILE"
fi

# Chargement de la configuration
source "$CONFIG_FILE"

# --- Fonction de mise à jour de la config ---
update_config_key() {
    local key=$1
    local value=$2
    # Échapper les caractères spéciaux pour sed si besoin
    if grep -q "^export $key=" "$CONFIG_FILE"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^export $key=.*|export $key=\"$value\"|" "$CONFIG_FILE"
        else
            sed -i "s|^export $key=.*|export $key=\"$value\"|" "$CONFIG_FILE"
        fi
    else
        echo "export $key=\"$value\"" >> "$CONFIG_FILE"
    fi
}

# --- Options TLS ---
TLS_OPTIONS=""
if [ "$INSECURE_SKIP_TLS_VERIFY" == "true" ]; then
    TLS_OPTIONS="--insecure-skip-tls-verify=true"
fi

# ==============================================================================
# LOGIQUE DE CONNEXION
# ==============================================================================

ensure_config_exists() {
    if [ -z "$SERVER_URL" ]; then
        echo "⚠️  URL manquante."
        read -p "👉 URL du cluster (ex: https://api...:6443) : " new_url
        update_config_key "SERVER_URL" "$new_url"
        SERVER_URL="$new_url"
    fi
    if [ -z "$TOKEN" ]; then
        echo "⚠️  Token manquant."
        read -s -p "👉 Token de connexion : " new_token
        echo ""
        update_config_key "TOKEN" "$new_token"
        TOKEN="$new_token"
    fi
}

check_session() {
    oc whoami > /dev/null 2>&1
    return $?
}

switch_namespace() {
    if [ ! -z "$DEFAULT_NAMESPACE" ]; then
        local CURRENT_NS=$(oc project -q 2>/dev/null)
        if [ "$CURRENT_NS" != "$DEFAULT_NAMESPACE" ]; then
            echo "📂 Activation du namespace : $DEFAULT_NAMESPACE"
            oc project "$DEFAULT_NAMESPACE" > /dev/null
        fi
    fi
}

do_login() {
    ensure_config_exists

    if check_session; then
        switch_namespace
        return
    fi

    echo "🔌 Connexion à $SERVER_URL..."
    oc login "$SERVER_URL" --token="$TOKEN" $TLS_OPTIONS > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        switch_namespace
    else
        echo "❌ Échec de la connexion (Token expiré ou invalide)."
        read -s -p "👉 Nouveau Token : " NEW_TOKEN
        echo ""
        if [ -z "$NEW_TOKEN" ]; then exit 1; fi

        update_config_key "TOKEN" "$NEW_TOKEN"
        TOKEN="$NEW_TOKEN"

        if oc login "$SERVER_URL" --token="$TOKEN" $TLS_OPTIONS > /dev/null 2>&1; then
            switch_namespace
        else
            echo "❌ Échec critique. Vérifiez l'URL ou vos droits."
            exit 1
        fi
    fi
}

do_logout() {
    echo "👋 Déconnexion..."
    oc logout
}

# ==============================================================================
# MENU DYNAMIQUE
# ==============================================================================

show_menu() {
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
    if [ ! -e "${files[0]}" ]; then
        echo "   (Aucun script trouvé dans $CMD_DIR/)"
        echo "=========================================="
        echo " q) Quitter & Logout"
        echo " x) Quitter (Garder session)"
        read -p "Votre choix ? " CHOICE
    else
        local i=1
        for f in "${files[@]}"; do
            # Recherche du tag # TITLE: dans le script
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
        echo "Bye."
        exit 0
    fi

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
    
    # On exporte les variables pour que les sous-scripts puissent les utiliser
    export DEFAULT_NAMESPACE
    export AUDIT_OUT_DIR
    
    # Exécution du script
    "$SELECTED_SCRIPT"
    
    echo "------------------------------------------"
    read -p "Appuyez sur Entrée pour revenir au menu..."
    show_menu
}

# Lancement
case "$1" in
    login) do_login ;;
    logout) do_logout ;;
    *) show_menu ;;
esac
