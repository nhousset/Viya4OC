#!/bin/bash
# TITLE: Extraction rapide des logs (Pods en échec/CrashLoop)

echo -e "\n=== [LOGS DES PODS EN ERREUR] ==="

# On cherche les pods qui ne sont pas en état Running ou Completed
BAD_PODS=$(oc get pods -n "$DEFAULT_NAMESPACE" --no-headers | awk '$3 != "Running" && $3 != "Completed" {print $1}')

if [ -z "$BAD_PODS" ]; then
    echo "✅ Tous les pods semblent stables (Running ou Completed)."
else
    for pod in $BAD_PODS; do
        echo -e "\n---------------------------------------------------"
        echo "📄 Logs récents pour le pod : $pod"
        echo "---------------------------------------------------"
        # On tente de récupérer les logs du conteneur principal. 
        # --all-containers=true peut être ajouté si nécessaire, mais pollue souvent la sortie.
        oc logs "$pod" -n "$DEFAULT_NAMESPACE" --tail=20 2>/dev/null || echo "Impossible de lire les logs (pod en cours de création ou détruit)."
    done
fi
