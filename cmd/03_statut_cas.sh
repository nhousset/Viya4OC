#!/bin/bash
# TITLE: Statut du moteur CAS (Cloud Analytic Services)

echo -e "\n=== [STATUT DU MOTEUR CAS] ==="

echo "🖥️  Pods du sous-système CAS :"
oc get pods -n "$DEFAULT_NAMESPACE" -l app.kubernetes.io/managed-by=sas-cas-operator

echo -e "\n📈 Consommation CPU/RAM des noeuds CAS :"
oc adm top pods -n "$DEFAULT_NAMESPACE" -l app.kubernetes.io/managed-by=sas-cas-operator 2>/dev/null || echo "Métriques indisponibles."

echo -e "\n⚙️  Ressources personnalisées CASDeployment :"
oc get casdeployments -n "$DEFAULT_NAMESPACE"
