#!/bin/bash
# TITLE: Tâches planifiées (CronJobs & Backups)

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}=== [ TÂCHES PLANIFIÉES (CRONJOBS & JOBS) ] ===${NC}"
echo -e "Namespace : ${YELLOW}$DEFAULT_NAMESPACE${NC}\n"

# 1. Liste des CronJobs (La planification)
echo -e "${YELLOW}⏱️  Liste des CronJobs configurés :${NC}"
CRONJOBS=$(oc get cronjobs -n "$DEFAULT_NAMESPACE" 2>/dev/null)

if [ -z "$CRONJOBS" ]; then
    echo -e "Aucun CronJob trouvé dans ce namespace."
else
    echo "$CRONJOBS"
fi

# 2. Vérification des Jobs récents (L'exécution)
echo -e "\n${YELLOW}⚙️  Statut des Jobs récents (En cours ou en erreur) :${NC}"

# On cherche les jobs qui n'ont pas la valeur "1/1" dans la colonne COMPLETIONS
# Cela inclut les jobs en train de tourner (0/1) ou ceux qui ont crashé.
FAILED_JOBS=$(oc get jobs -n "$DEFAULT_NAMESPACE" --no-headers 2>/dev/null | awk '$2 != "1/1" {print $0}')

if [ -z "$FAILED_JOBS" ]; then
    echo -e "${GREEN}✅ Tous les jobs récents se sont terminés avec succès.${NC}"
else
    printf "${BOLD}%-55s %-15s %-10s %s${NC}\n" "NOM DU JOB" "COMPLETIONS" "DURATION" "AGE"
    echo "------------------------------------------------------------------------------------------------"
    
    # On colore différemment selon si c'est "en cours" (0/1 récent) ou si c'est vraiment planté
    while read -r line; do
        if [[ -n "$line" ]]; then
            echo -e "${RED}$line${NC}"
        fi
    done <<< "$FAILED_JOBS"
    
    echo "------------------------------------------------------------------------------------------------"
    echo -e "💡 ${CYAN}Note : Si 'COMPLETIONS' est à 0/1 et 'DURATION' s'incrémente, le job est en cours d'exécution.${NC}"
fi
