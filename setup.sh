#!/bin/bash
# ==============================================================================
# Fichier : setup.sh
# Description : Assistant de configuration pour l'outil d'audit SAS Viya 4
# ==============================================================================

CONFIG_FILE="config.env"

clear
echo "================================================="
echo "   Assistant de configuration - SAS Viya Audit   "
echo "================================================="
echo "Ce script va générer votre fichier $CONFIG_FILE."
echo ""

# Vérifier si un fichier existe déjà pour éviter de l'écraser par erreur
if [ -f "$CONFIG_FILE" ]; then
    read -p "⚠️ Le fichier $CONFIG_FILE existe déjà. Voulez-vous l'écraser ? (o/n) : " overwrite
    if [[ ! "$overwrite" =~ ^[oO]$ ]]; then
        echo "Configuration annulée. Le fichier existant a été conservé."
        exit 0
    fi
    echo ""
fi

# --- SAISIE INTERACTIVE ---

# 1. URL
read -p "1️⃣  Entrez l'URL de l'API OpenShift (ex: https://api.cluster.com:6443) : " oc_url

# 2. Token (utilisation de -s pour cacher la saisie)
read -s -p "2️⃣  Entrez votre Token de connexion OpenShift (la saisie est masquée) : " oc_token
echo "" # Retour à la ligne nécessaire après un read -s

# 3. Namespace (avec valeur par défaut)
read -p "3️⃣  Entrez le nom du namespace SAS Viya [sas-viya] : " viya_namespace
viya_namespace=${viya_namespace:-sas-viya} # Assigne 'sas-viya' si l'utilisateur appuie juste sur Entrée

# 4. Dossier de sortie (avec valeur par défaut)
read -p "4️⃣  Entrez le dossier de sortie des rapports [./rapports_audit] : " out_dir
out_dir=${out_dir:-./rapports_audit}

# 5. Gestion du TLS
read -p "5️⃣  Ignorer la vérification TLS (certificats auto-signés) ? (true/false) [false] : " skip_tls
skip_tls=${skip_tls:-false}

# --- GÉNÉRATION DU FICHIER ---

echo ""
echo "⏳ Création du fichier $CONFIG_FILE..."

# Utilisation d'un bloc 'cat' pour écrire facilement de multiples lignes
cat <<EOF > "$CONFIG_FILE"
#!/bin/bash
# ==============================================================================
# Fichier : config.env (Généré automatiquement le $(date +%Y-%m-%d))
# ==============================================================================

export OC_URL="$oc_url"
export OC_TOKEN="$oc_token"
export VIYA_NAMESPACE="$viya_namespace"
export AUDIT_OUT_DIR="$out_dir"
export INSECURE_SKIP_TLS_VERIFY="$skip_tls"
EOF

# --- SÉCURITÉ ---
# On restreint les droits du fichier car il contient un token d'authentification sensible
chmod 600 "$CONFIG_FILE"

echo "✅ Configuration terminée avec succès !"
echo "🔒 Les permissions de $CONFIG_FILE ont été restreintes (chmod 600) par sécurité."
echo "🚀 Vous pouvez maintenant lancer votre audit avec : ./viya4_audit.sh"
echo "================================================="
