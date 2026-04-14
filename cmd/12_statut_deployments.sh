#!/bin/bash
# TITLE: Statut des Déploiements (Microservices)

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}=== [ STATUT DES DÉPLOIEMENTS (MICROSERVICES) ] ===${NC}"
echo -e "Namespace : ${YELLOW}$DEFAULT_NAMESPACE${NC}\n"

echo -e "${YELLOW}📊 Résumé global :${NC}"
# Calcul du total et de ceux qui sont 100% prêts
TOTAL=$(oc get deploy -n "$DEFAULT_NAMESPACE" --no-headers 2>/dev/null | wc -l)
AVAILABLE=$(oc get deploy -n "$DEFAULT_NAMESPACE" --no-headers 2>/dev/null | awk '{split($2,a,"/"); if(a[1]==a[2] && a[1]>0) count++} END {print count+0}')

echo -e "Déploiements totaux  : ${CYAN}$TOTAL${NC}"
if [ "$TOTAL" -eq "$AVAILABLE" ] && [ "$TOTAL" -gt 0 ]; then
    echo -e "Déploiements prêts   : ${GREEN}$AVAILABLE${NC}"
else
    echo -e "Déploiements prêts   : ${RED}$AVAILABLE${NC}"
fi

echo -e "\n${YELLOW}🚨 Déploiements en anomalie (Non Ready) :${NC}"
# awk analyse la colonne 2 (READY, ex: 1/1). Il isole ceux où le chiffre de gauche est différent de celui de droite.
BAD_DEPLOY=$(oc get deploy -n "$DEFAULT_NAMESPACE" --no-headers 2>/dev/null | awk '{split($2,a,"/"); if(a[1]!=a[2] || (a[2]>0 && a[1]==0)) print $0}')

if [ -z "$BAD_DEPLOY" ]; then
    echo -e "${GREEN}✅ Tous les microservices sont à 100% de disponibilité.${NC}"
else
    printf "${BOLD}%-45s %-10s %-12s %-10s %s${NC}\n" "NOM DU MICROSERVICE" "READY" "UP-TO-DATE" "AVAILABLE" "AGE"
    echo "----------------------------------------------------------------------------------------"
    echo -e "${RED}$BAD_DEPLOY${NC}"
    echo "----------------------------------------------------------------------------------------"
    echo -e "💡 ${CYAN}Astuce : Utilisez 'oc describe deploy <nom>' pour comprendre pourquoi il ne démarre pas.${NC}"
fi
