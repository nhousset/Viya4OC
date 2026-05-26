#!/bin/bash
# TITLE: Audit du stockage (PV, PVC, Evénements)
echo -e "\n=== [AUDIT DU STOCKAGE] ==="
# On définit le namespace par défaut si ce n'est pas déjà fait
export DEFAULT_NAMESPACE="${DEFAULT_NAMESPACE:-default}"
# On exécute le programme Go qui prend le relais pour le reste
./audit_stockage
