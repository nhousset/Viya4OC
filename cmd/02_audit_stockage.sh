#!/bin/bash
# TITLE: Audit du stockage (PV, PVC, Evénements)

echo -e "\n=== [AUDIT DU STOCKAGE] ==="

echo "📊 État des Persistent Volume Claims (PVC) :"
oc get pvc -n "$DEFAULT_NAMESPACE"

echo -e "\n⚠️  Événements récents liés à des erreurs de volumes (Warning) :"
# On filtre les events Kubernetes pour ne garder que les alertes de montage/stockage
EVENTS=$(oc get events -n "$DEFAULT_NAMESPACE" --field-selector type=Warning | grep -i -E "volume|pvc|storage")

if [ -z "$EVENTS" ]; then
    echo "✅ Aucun problème de volume récent détecté dans les événements."
else
    echo "$EVENTS"
fi
