#!/bin/bash
# TITLE: Démarrer / Arrêter l'environnement Viya 4

# --- Couleurs ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# FONCTIONS D'ACTION
# ==============================================================================

start_viya() {
    echo -e "\n${YELLOW}⚠️  Lancement de la procédure de démarrage global de SAS Viya 4...${NC}"
    read -p "👉 Voulez-vous vraiment DÉMARRER l'environnement dans le namespace '$DEFAULT_NAMESPACE' ? (o/N) : " confirm
    
    if [[ "$confirm" =~ ^[oO]$ ]]; then
        local job_name="sas-start-all-$(date +%s)"
        echo -e "\n${CYAN}Création du job : ${BOLD}$job_name${NC}"
        
        # Commande officielle de démarrage Viya 4
        oc create job "$job_name" --from cronjobs/sas-start-all -n "$DEFAULT_NAMESPACE"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Job de démarrage créé avec succès.${NC}"
            echo -e "${YELLOW}Vous pouvez suivre les logs du job en direct avec cette commande (ou utiliser l'option 3) :${NC}"
            echo -e "oc logs -f job/$job_name -n $DEFAULT_NAMESPACE"
        else
            echo -e "${RED}❌ Erreur lors de la création du job de démarrage.${NC}"
            echo -e "Vérifiez que le CronJob 'sas-start-all' existe dans le namespace."
        fi
    else
        echo -e "${GREEN}Action annulée.${NC}"
    fi
}

stop_viya() {
    echo -e "\n${RED}⚠️  ATTENTION : Cette action va interrompre tous les services SAS Viya 4 en cours.${NC}"
    read -p "👉 Voulez-vous vraiment ARRÊTER l'environnement dans le namespace '$DEFAULT_NAMESPACE' ? (o/N) : " confirm
    
    if [[ "$confirm" =~ ^[oO]$ ]]; then
        local job_name="sas-stop-all-$(date +%s)"
        echo -e "\n${CYAN}Création du job : ${BOLD}$job_name${NC}"
        
        # Commande officielle d'arrêt Viya 4
        oc create job "$job_name" --from cronjobs/sas-stop-all -n "$DEFAULT_NAMESPACE"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Job d'arrêt créé avec succès.${NC}"
            echo -e "${YELLOW}Vous pouvez suivre les logs du job en direct avec cette commande (ou utiliser l'option 3) :${NC}"
            echo -e "oc logs -f job/$job_name -n $DEFAULT_NAMESPACE"
        else
            echo -e "${RED}❌ Erreur lors de la création du job d'arrêt.${NC}"
            echo -e "Vérifiez que le CronJob 'sas-stop-all' existe dans le namespace."
        fi
    else
        echo -e "${GREEN}Action annulée.${NC}"
    fi
}

check_status() {
    echo -e "\n${CYAN}=== [ HISTORIQUE DES JOBS START / STOP ] ===${NC}"
    echo -e "${YELLOW}Derniers jobs de démarrage/arrêt :${NC}"
    
    # Affichage du header des jobs
    oc get jobs -n "$DEFAULT_NAMESPACE" 2>/dev/null | head -n 1
    
    # Récupération des jobs filtrés et triés chronologiquement
    local jobs_list=$(oc get jobs -n "$DEFAULT_NAMESPACE" --sort-by=.metadata.creationTimestamp 2>/dev/null | grep -E "sas-start-all|sas-stop-all")
    
    if [ -n "$jobs_list" ]; then
        # Affichage des 5 derniers pour la lisibilité
        echo "$jobs_list" | tail -n 5
        
        echo -e "\n${CYAN}--------------------------------------------------------------${NC}"
        # On récupère le nom exact du dernier job créé
        local last_job=$(echo "$jobs_list" | tail -n 1 | awk '{print $1}')
        
        read -p "👉 Voulez-vous afficher les logs du dernier job ($last_job) ? (o/N) : " view_logs
        if [[ "$view_logs" =~ ^[oO]$ ]]; then
            echo -e "\n${YELLOW}⏳ Récupération des logs pour $last_job...${NC}"
            oc logs "job/$last_job" -n "$DEFAULT_NAMESPACE" 2>/dev/null || echo -e "${RED}Logs indisponibles (le job n'a peut-être pas encore démarré ses pods).${NC}"
            echo -e "${CYAN}--------------------------------------------------------------${NC}"
        fi
    else
        echo -e "${RED}Aucun job sas-start-all ou sas-stop-all n'a été trouvé dans le namespace '$DEFAULT_NAMESPACE'.${NC}"
    fi
    
    read -p "Appuyez sur Entrée pour revenir au menu..."
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================
while true; do
    clear
    echo -e "${CYAN}=== [ DÉMARRAGE ET ARRÊT DE SAS VIYA 4 ] ===${NC}"
    echo -e "Namespace : ${YELLOW}$DEFAULT_NAMESPACE${NC}\n"
    
    echo -e " ${BOLD}1)${NC} 🚀 Démarrer l'environnement SAS Viya 4 (sas-start-all)"
    echo -e " ${BOLD}2)${NC} 🛑 Arrêter l'environnement SAS Viya 4 (sas-stop-all)"
    echo -e " ${BOLD}3)${NC} 📊 Historique et Logs des actions de démarrage/arrêt"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${RED}q)${NC} Retour au menu principal"
    echo ""
    read -p "👉 Votre choix : " main_choice

    case "$main_choice" in
        1) start_viya ; sleep 2 ;;
        2) stop_viya ; sleep 2 ;;
        3) check_status ;;
        q|Q) break ;;
        *) echo -e "${RED}Choix invalide.${NC}" ; sleep 1 ;;
    esac
done
