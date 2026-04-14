#!/bin/bash
# ==============================================================================
# Fichier : viya4_audit.sh
# Description : Script d'audit SAS Viya 4 modulaire avec passage d'arguments
# ==============================================================================

set -e

# --- FONCTION D'AIDE ---
afficher_aide() {
    echo "================================================="
    echo "   Outil d'Audit SAS Viya 4 sur OpenShift        "
    echo "================================================="
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options disponibles :"
    echo "  -n    Auditer les noeuds (Nodes & Ressources)"
    echo "  -p    Auditer les pods (Statuts & Top 10 CPU/RAM)"
    echo "  -s    Auditer le réseau (Services & Routes)"
    echo "  -l    Auditer les limites (Quotas & LimitRanges)"
    echo "  -a    Tout auditer (équivalent à -n -p -s -l)"
    echo "  -h    Afficher cette page d'aide"
    echo ""
    echo "Exemple :"
    echo "  $0 -p -s    # Audite uniquement les pods et le réseau"
    echo "  $0 -a       # Lance un audit complet"
    exit 1
}

# Si aucun argument n'est passé, on affiche l'aide
if [ $# -eq 0 ]; then
    afficher_aide
fi

# --- GESTION DES ARGUMENTS ---
AUDIT_NODES=false
AUDIT_PODS=false
AUDIT_NETWORK=false
AUDIT_LIMITS=false

while getopts "npslah" opt; do
    case $opt in
        n) AUDIT_NODES=true ;;
        p) AUDIT_PODS=true ;;
        s) AUDIT_NETWORK=true ;;
        l) AUDIT_LIMITS=true ;;
        a) AUDIT_NODES=true; AUDIT_PODS=true; AUDIT_NETWORK=true; AUDIT_LIMITS=true ;;
        h) afficher_aide ;;
        \?) echo "Option invalide. Utilisez -h pour l'aide."; exit 1 ;;
    esac
done

# --- CHARGEMENT DE LA CONFIGURATION ---
if [ -f "config.env" ]; then
    source config.env
else
    echo "❌ Erreur : Le fichier config.env est introuvable."
    exit 1
fi

# --- CONFIGURATION TLS ET FICHIER DE SORTIE ---
TLS_FLAG=""
if [ "$INSECURE_SKIP_TLS_VERIFY" = "true" ]; then
    TLS_FLAG="--insecure-skip-tls-verify=true"
fi

mkdir -p "$AUDIT_OUT_DIR"
REPORT_FILE="${AUDIT_OUT_DIR}/audit_viya_${VIYA_NAMESPACE}_$(date +%Y%m%d_%H%M%S).txt"

# --- FONCTION DE CONNEXION ---
connect_oc() {
    echo "🔄 Connexion au cluster : $OC_URL..."
    if oc login --server="$OC_URL" --token="$OC_TOKEN" $TLS_FLAG > /dev/null 2>&1; then
        oc project "$VIYA_NAMESPACE" > /dev/null 2>&1
        echo "✅ Connecté sur le namespace : $VIYA_NAMESPACE"
    else
        echo "❌ Échec de la connexion. Vérifiez config.env."
        exit 1
    fi
}

# --- FONCTIONS D'AUDIT ---

audit_nodes() {
    echo -e "\n=== [AUDIT DES NOEUDS] ===" | tee -a "$REPORT_FILE"
    oc get nodes -o wide | tee -a "$REPORT_FILE"
    echo -e "\nConsommation des ressources par noeud :" | tee -a "$REPORT_FILE"
    oc adm top nodes 2>/dev/null || echo "Métriques indisponibles." | tee -a "$REPORT_FILE"
}

audit_pods() {
    echo -e "\n=== [AUDIT DES PODS] ===" | tee -a "$REPORT_FILE"
    local total_pods=$(oc get pods -n "$VIYA_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    local running_pods=$(oc get pods -n "$VIYA_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    echo "Total des pods     : $total_pods" | tee -a "$REPORT_FILE"
    echo "Pods en exécution  : $running_pods" | tee -a "$REPORT_FILE"
    
    echo -e "\nListe des pods en anomalie (hors Running/Completed) :" | tee -a "$REPORT_FILE"
    oc get pods -n "$VIYA_NAMESPACE" | awk '$3 != "Running" && $3 != "Completed" && NR>1' | tee -a "$REPORT_FILE"
    
    echo -e "\nTop 10 pods (CPU/RAM) :" | tee -a "$REPORT_FILE"
    oc adm top pods -n "$VIYA_NAMESPACE" 2>/dev/null | sort -k 3 -r | head -n 11 | tee -a "$REPORT_FILE"
}

audit_services_routes() {
    echo -e "\n=== [AUDIT DU RESEAU] ===" | tee -a "$REPORT_FILE"
    echo "Services exposés :" | tee -a "$REPORT_FILE"
    oc get svc -n "$VIYA_NAMESPACE" | tee -a "$REPORT_FILE"
    echo -e "\nRoutes OpenShift :" | tee -a "$REPORT_FILE"
    oc get routes -n "$VIYA_NAMESPACE" | tee -a "$REPORT_FILE"
}

audit_limits_quotas() {
    echo -e "\n=== [AUDIT DES LIMITES ET QUOTAS] ===" | tee -a "$REPORT_FILE"
    echo "Resource Quotas :" | tee -a "$REPORT_FILE"
    oc get resourcequotas -n "$VIYA_NAMESPACE" | tee -a "$REPORT_FILE"
    echo -e "\nLimit Ranges :" | tee -a "$REPORT_FILE"
    oc get limitranges -n "$VIYA_NAMESPACE" | tee -a "$REPORT_FILE"
}

# --- EXECUTION PRINCIPALE ---
clear
echo "🚀 Démarrage de l'audit sélectif..."
connect_oc
echo "📄 Les résultats seront écrits dans : $REPORT_FILE"
echo "-------------------------------------------------"

# Exécution conditionnelle basée sur les arguments
if [ "$AUDIT_NODES" = true ]; then audit_nodes; fi
if [ "$AUDIT_PODS" = true ]; then audit_pods; fi
if [ "$AUDIT_NETWORK" = true ]; then audit_services_routes; fi
if [ "$AUDIT_LIMITS" = true ]; then audit_limits_quotas; fi

echo "-------------------------------------------------"
echo "✅ Opération terminée."
