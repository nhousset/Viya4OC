#!/bin/bash
# TITLE: Statut des bases PostgreSQL (CrunchyData)

echo -e "\n=== [STATUT DE L'INFRASTRUCTURE POSTGRESQL] ==="

echo "🗄️  Clusters PostgreSQL (PostgresCluster) :"
oc get postgrescluster -n "$DEFAULT_NAMESPACE" 2>/dev/null || echo "Aucune ressource PostgresCluster trouvée."

echo -e "\n🐳 Pods de la base de données (Master & Replicas) :"
oc get pods -n "$DEFAULT_NAMESPACE" -l postgres-operator.crunchydata.com/data=postgres
