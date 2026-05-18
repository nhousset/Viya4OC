#!/bin/bash
# TITLE: Suivi des logs en direct (Tail) - Apps Critiques

# --- Couleurs ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# CONFIGURATION DES APPLICATIONS À SURVEILLER
# Ajoutez ici les préfixes des pods que vous souhaitez surveiller régulièrement.
# ==============================================================================
APPS_TO_MONITOR=(
    "sas-logon-app"
    "sas-identities"
    # "sas-drive-app"     <-- Décommentez ou ajoutez d'autres apps ici
    # "sas-compute-spawner"
)

while true; do
    clear
    echo -e "${CYAN}=== [ SUIVI DES LOGS EN DIRECT (TAIL -F) ] ===${NC}"
    echo -e "Namespace : ${YELLOW}$DEFAULT_NAMESPACE${NC}\n"
    
    echo "Choisissez l'application à surveiller :"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    
    # Affichage dynamique du menu basé sur le tableau
    for i in "${!APPS_TO_MONITOR[@]}"; do
        # On ajoute 1 à l'index pour que le menu commence à 1
        echo -e " ${BOLD}$((i+1)))${NC} ${APPS_TO_MONITOR[$i]}"
    done
    
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${RED}q)${NC} Retour au menu principal"
    echo ""
    read -p "👉 Votre choix : " choice

    if [[ "$choice" == "q" ]]; then
        break # Quitte ce plugin et retourne à viya.sh
    fi

    # Validation du choix (doit être un nombre valide correspondant au tableau)
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#APPS_TO_MONITOR[@]}" ]; then
        
        # Récupération du nom de base choisi (index - 1)
        selected_app="${APPS_TO_MONITOR[$((choice-1))]}"
        
        echo -e "\n${YELLOW}🔍 Recherche d'un pod actif pour '${selected_app}'...${NC}"
        
        # On cherche le vrai nom du pod (qui commence par le nom de l'app et qui est en Running)
        # On utilise head -n 1 au cas où il y a plusieurs replicas (on prendra le premier)
        POD_NAME=$(oc get pods -n "$DEFAULT_NAMESPACE" --no-headers | grep "^${selected_app}-" | grep "Running" | head -n 1 | awk '{print $1}')
        
        if [ -z "$POD_NAME" ]; then
            echo -e "${RED}❌ Aucun pod en cours d'exécution (Running) trouvé pour ${selected_app}.${NC}"
            sleep 2
        else
            echo -e "${GREEN}✅ Pod trouvé : $POD_NAME${NC}"
            echo -e "${CYAN}--------------------------------------------------------------${NC}"
            echo -e "Affichage des logs en continu... ${YELLOW}(Appuyez sur Ctrl+C pour arrêter le défilement)${NC}"
            echo -e "${CYAN}--------------------------------------------------------------${NC}"
            
            # Lancement du tail (-f pour follow)
            oc logs -f "$POD_NAME" -n "$DEFAULT_NAMESPACE"
            
            # Une fois que l'utilisateur fait Ctrl+C, le script reprend ici
            echo -e "\n${YELLOW}Fin de la lecture des logs.${NC}"
            read -p "Appuyez sur Entrée pour revenir à la liste..."
        fi
    else
        echo -e "${RED}Choix invalide.${NC}"
        sleep 1
    fi
done
