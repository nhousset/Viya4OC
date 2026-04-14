#!/bin/bash
# TITLE: Audit des Limites et Quotas (CPU/RAM)

echo -e "\n=== [AUDIT DES LIMITES ET QUOTAS] ==="
echo "Namespace cible : $DEFAULT_NAMESPACE"

# 1. Vérification des ResourceQuotas (Limites globales du projet)
echo -e "\n📊 Resource Quotas (Limites globales du projet) :"
QUOTAS=$(oc get resourcequotas -n "$DEFAULT_NAMESPACE" --no-headers 2>/dev/null)

if [ -z "$QUOTAS" ]; then
    echo "✅ Aucun ResourceQuota défini sur ce namespace. Le projet n'est pas bridé globalement."
else
    # On utilise describe pour voir exactement ce qui est consommé vs la limite
    oc describe resourcequotas -n "$DEFAULT_NAMESPACE"
    
    echo -e "\n💡 Astuce : Si une ressource est proche de sa limite 'Hard', de nouveaux pods pourraient rester en 'Pending'."
fi

# 2. Vérification des LimitRanges (Limites par défaut par conteneur/pod)
echo -e "\n🎯 Limit Ranges (Règles par défaut par Pod/Conteneur) :"
LIMITS=$(oc get limitranges -n "$DEFAULT_NAMESPACE" --no-headers 2>/dev/null)

if [ -z "$LIMITS" ]; then
    echo "✅ Aucun LimitRange défini sur ce namespace."
else
    oc describe limitranges -n "$DEFAULT_NAMESPACE"
    
    echo -e "\n💡 Astuce : Les LimitRanges forcent des 'requests' et 'limits' sur les pods qui n'en déclarent pas."
    echo "Dans SAS Viya, cela peut impacter le démarrage des sessions Compute si elles sont mal dimensionnées."
fi

echo -e "\n---------------------------------------------------"
