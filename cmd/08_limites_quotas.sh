#!/bin/bash
# TITLE: Audit des Limites et Quotas (CPU/RAM)

export DEFAULT_NAMESPACE="${DEFAULT_NAMESPACE:-default}"

echo -e "\n=== [AUDIT DES LIMITES ET QUOTAS] ==="
echo "Namespace cible : $DEFAULT_NAMESPACE"

./limites_quotas
