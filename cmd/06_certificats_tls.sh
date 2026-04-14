#!/bin/bash
# TITLE: Vérification des Certificats TLS (cert-manager)

echo -e "\n=== [STATUT DES CERTIFICATS TLS] ==="

echo "🔐 Certificats gérés par cert-manager :"
oc get certificates -n "$DEFAULT_NAMESPACE" 2>/dev/null || echo "Aucun certificat cert-manager trouvé."

echo -e "\n🔑 Secrets contenant des certificats TLS :"
oc get secrets -n "$DEFAULT_NAMESPACE" --field-selector type=kubernetes.io/tls -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp
