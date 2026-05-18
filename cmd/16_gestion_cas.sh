#!/bin/bash
# TITLE: Gestion du Serveur CAS (Start / Stop / Status)

# --- Couleurs ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# CONFIGURATION DES SERVEURS CAS
# Ajoutez ici le ou les noms de vos déploiements CAS (casdeployment).
# Le nom par défaut dans Viya 4 est généralement "default".
# ==============================================================================
CAS_SERVERS=(
    "default"
    # "shared-default"  <-- Décommentez ou modifiez selon votre environnement
)

# ==============================================================================
# FONCTIONS D'ACTION
# ==============================================================================

afficher_status() {
    local cas_name="$1"
    echo -e "\n${CYAN}=== [ STATUT DU SERVEUR CAS : ${YELLOW}$cas_name${CYAN} ] ===${NC}"
    
    # 1. Vérification de l'objet CASDeployment
    echo -e "${YELLOW}⚙️  Ressource CASDeployment :${NC}"
    oc get casdeployment "$cas_name" -n "$DEFAULT_NAMESPACE" 2>/dev/null || echo -e "${RED}CASDeployment '$cas_name' introuvable.${NC}"
    
    # 2. Vérification des pods (Controller et Workers)
    echo -e "\n${YELLOW}🖥️  Pods associés (Controller & Workers) :${NC}"
    # L'opérateur CAS tague toujours ses pods avec ce label
    oc get pods -n "$DEFAULT_NAMESPACE" -l "casoperator.sas.com/server=$cas_name"
    
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    read -p "Appuyez sur Entrée pour continuer..."
}

arreter_cas() {
    local cas_name="$1"
    echo -e "\n${RED}⚠️  ATTENTION : L'arrêt du serveur CAS va déconnecter toutes les sessions analytiques en cours et purger les données in-memory non sauvegardées.${NC}"
    read -p "👉 Voulez-vous VRAIMENT arrêter le CAS '$cas_name' ? (o/N) : " confirm
    
    if [[ "$confirm" =~ ^[oO]$ ]]; then
        echo -e "${YELLOW}⏳ Envoi de l'instruction d'arrêt (Shutdown) à l'opérateur...${NC}"
        # On patch la ressource pour mettre shutdown: true
        oc patch casdeployment "$cas_name" -n "$DEFAULT_NAMESPACE" --type=merge -p '{"spec":{"shutdown":true}}'
        echo -e "${GREEN}✅ Commande d'arrêt envoyée. Les pods vont se terminer progressivement.${NC}"
    else
        echo -e "${GREEN}Action annulée.${NC}"
    fi
    sleep 2
}

demarrer_cas() {
    local cas_name="$1"
    echo -e "\n${YELLOW}⏳ Envoi de l'instruction de démarrage à l'opérateur...${NC}"
    # On patch la ressource pour mettre shutdown: false
    oc patch casdeployment "$cas_name" -n "$DEFAULT_NAMESPACE" --type=merge -p '{"spec":{"shutdown":false}}'
    echo -e "${GREEN}✅ Commande de démarrage envoyée. L'opérateur va provisionner le Controller puis les Workers.${NC}"
    sleep 2
}

# ==============================================================================
# MENU PRINCIPAL (CHOIX DU SERVEUR)
# ==============================================================================
while true; do
    clear
    echo -e "${CYAN}=== [ GESTION DU SERVEUR CAS (CLOUD ANALYTIC SERVICES) ] ===${NC}"
    echo -e "Namespace : ${YELLOW}$DEFAULT_NAMESPACE${NC}\n"
    
    echo "Choisissez le serveur CAS à administrer :"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    
    for i in "${!CAS_SERVERS[@]}"; do
        echo -e " ${BOLD}$((i+1)))${NC} ${CAS_SERVERS[$i]}"
    done
    
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${RED}q)${NC} Retour au menu principal"
    echo ""
    read -p "👉 Votre choix : " srv_choice

    if [[ "$srv_choice" == "q" ]]; then
        break
    fi

    # Validation du choix du serveur
    if [[ "$srv_choice" =~ ^[0-9]+$ ]] && [ "$srv_choice" -ge 1 ] && [ "$srv_choice" -le "${#CAS_SERVERS[@]}" ]; then
        SELECTED_CAS="${CAS_SERVERS[$((srv_choice-1))]}"
        
        # ==============================================================================
        # SOUS-MENU (ACTIONS SUR LE SERVEUR)
        # ==============================================================================
        while true; do
            clear
            echo -e "${CYAN}==============================================================${NC}"
            echo -e " ⚙️  ACTIONS SUR LE CAS : ${YELLOW}$SELECTED_CAS${NC}"
            echo -e "${CYAN}==============================================================${NC}"
            
            echo -e " ${BOLD}1)${NC} 📊 Afficher le statut (Pods & Ressources)"
            echo -e " ${BOLD}2)${NC} 🚀 Démarrer le serveur (Start)"
            echo -e " ${BOLD}3)${NC} 🛑 Arrêter le serveur (Stop)"
            echo -e "${CYAN}--------------------------------------------------------------${NC}"
            echo -e " ${RED}r)${NC} Retour au choix du serveur"
            echo ""
            read -p "👉 Votre action : " act_choice
            
            case "$act_choice" in
                1) afficher_status "$SELECTED_CAS" ;;
                2) demarrer_cas "$SELECTED_CAS" ;;
                3) arreter_cas "$SELECTED_CAS" ;;
                r) break ;; # Remonte à la sélection du serveur
                *) echo -e "${RED}Choix invalide.${NC}" ; sleep 1 ;;
            esac
        done
        
    else
        echo -e "${RED}Choix invalide.${NC}"
        sleep 1
    fi
done
