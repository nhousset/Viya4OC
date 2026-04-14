#!/bin/bash
# TITLE: Audit de santé complet (Noeuds, Pods, Réseau, Limites)

# Le menu principal garantit que ce dossier existe, mais par sécurité :
mkdir -p "${AUDIT_OUT_DIR:-./rapports_audit}"
REPORT_FILE="${AUDIT_OUT_DIR:-./rapports_audit}/audit_viya_${DEFAULT_NAMESPACE}_$(date +%Y%m%d_%H%M%S).txt"

echo "📄 Les résultats seront écrits dans : $REPORT_FILE"

# --- FONCTIONS ---

audit_nodes() {
    echo -e "\n=== [AUDIT DES NOEUDS] ===" | tee -a "$REPORT_FILE"
    oc get nodes -o wide | tee -a "$REPORT_FILE"
    echo -e "\nConsommation des ressources par noeud :" | tee -a "$REPORT_FILE"
    oc adm top nodes 2>/dev/null || echo "Métriques indisponibles." | tee -a "$REPORT_FILE"
}

audit_pods() {
    echo -e "\n=== [AUDIT DES PODS] ===" | tee -a "$REPORT_FILE"
    local total_pods=$(oc get pods -n "$DEFAULT_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    local running_pods=$(oc get pods -n "$DEFAULT_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    echo "Total des pods     : $total_pods" | tee -a "$REPORT_FILE"
    echo "Pods en exécution  : $running_pods" | tee -a "$REPORT_FILE"
    
    echo -e "\nListe des pods en anomalie (hors Running/Completed) :" | tee -a "$REPORT_FILE"
    oc get pods -n "$DEFAULT_NAMESPACE" | awk '$3 != "Running" && $3 != "Completed" && NR>1' | tee -a "$REPORT_FILE"
    
    echo -e "\nTop 10 pods (CPU/RAM) :" | tee -a "$REPORT_FILE"
    oc adm top pods -n "$DEFAULT_NAMESPACE" 2>/dev/null | sort -k 3 -r | head -n 11 | tee -a "$REPORT_FILE"
}

audit_services_routes() {
    echo -e "\n=== [AUDIT DU RESEAU] ===" | tee -a "$REPORT_FILE"
    echo "Services exposés :" | tee -a "$REPORT_FILE"
    oc get svc -n "$DEFAULT_NAMESPACE" | tee -a "$REPORT_FILE"
    echo -e "\nRoutes OpenShift :" | tee -a "$REPORT_FILE"
    oc get routes -n "$DEFAULT_NAMESPACE" | tee -a "$REPORT_FILE"
}

audit_limits_quotas() {
    echo -e "\n=== [AUDIT DES LIMITES ET QUOTAS] ===" | tee -a "$REPORT_FILE"
    echo "Resource Quotas :" | tee -a "$REPORT_FILE"
    oc get resourcequotas -n "$DEFAULT_NAMESPACE" | tee -a "$REPORT_FILE"
    echo -e "\nLimit Ranges :" | tee -a "$REPORT_FILE"
    oc get limitranges -n "$DEFAULT_NAMESPACE" | tee -a "$REPORT_FILE"
}

# --- EXECUTION ---
audit_nodes
audit_pods
audit_services_routes
audit_limits_quotas

echo "✅ Audit terminé avec succès."
