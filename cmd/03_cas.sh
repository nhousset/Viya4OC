#!/bin/bash
# TITLE: Gestion & Statut du Moteur CAS (Global, Opérateur, Contrôleur)

# --- Couleurs ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# CONFIGURATION DES SERVEURS CAS
# ==============================================================================
CAS_SERVERS=(
    "default"
    # "shared-default"
)

# ==============================================================================
# FONCTIONS D'ACTION
# ==============================================================================

afficher_statut_global() {
    echo -e "\n${CYAN}=== [ STATUT GLOBAL DU MOTEUR CAS ] ===${NC}"
    
    echo -e "${YELLOW}⚙️  Ressources CASDeployments :${NC}"
    oc get casdeployments -n "$DEFAULT_NAMESPACE" 2>/dev/null || echo -e "${RED}Aucun CASDeployment trouvé.${NC}"
    
    echo -e "\n${YELLOW}🖥️  Tous les pods du sous-système CAS :${NC}"
    oc get pods -n "$DEFAULT_NAMESPACE" -l app.kubernetes.io/managed-by=sas-cas-operator 2>/dev/null
    
    echo -e "\n${YELLOW}📈 Consommation CPU/RAM des noeuds CAS :${NC}"
    oc adm top pods -n "$DEFAULT_NAMESPACE" -l app.kubernetes.io/managed-by=sas-cas-operator 2>/dev/null || echo -e "${RED}Métriques indisponibles.${NC}"
    
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    read -p "Appuyez sur Entrée pour continuer..."
}

afficher_statut_cas() {
    local cas_name="$1"
    echo -e "\n${CYAN}=== [ STATUT DU SERVEUR CAS : ${YELLOW}$cas_name${CYAN} ] ===${NC}"
    
    echo -e "${YELLOW}⚙️  Ressource CASDeployment :${NC}"
    oc get casdeployment "$cas_name" -n "$DEFAULT_NAMESPACE" 2>/dev/null || echo -e "${RED}CASDeployment '$cas_name' introuvable.${NC}"
    
    echo -e "\n${YELLOW}🖥️  Pods associés (Controller & Workers) :${NC}"
    oc get pods -n "$DEFAULT_NAMESPACE" -l "casoperator.sas.com/server=$cas_name" 2>/dev/null
}

arreter_cas() {
    local cas_name="$1"
    echo -e "\n${RED}⚠️  ATTENTION : L'arrêt du serveur CAS va déconnecter toutes les sessions analytiques en cours et purger les données in-memory non sauvegardées.${NC}"
    read -p "👉 Voulez-vous VRAIMENT arrêter le CAS '$cas_name' ? (o/N) : " confirm
    
    if [[ "$confirm" =~ ^[oO]$ ]]; then
        echo -e "${YELLOW}⏳ Envoi de l'instruction d'arrêt (Shutdown) à l'opérateur...${NC}"
        oc patch casdeployment "$cas_name" -n "$DEFAULT_NAMESPACE" --type=merge -p '{"spec":{"shutdown":true}}'
        echo -e "${GREEN}✅ Commande d'arrêt envoyée. Les pods vont se terminer progressivement.${NC}"
    else
        echo -e "${GREEN}Action annulée.${NC}"
    fi
}

demarrer_cas() {
    local cas_name="$1"
    echo -e "\n${YELLOW}⏳ Envoi de l'instruction de démarrage à l'opérateur...${NC}"
    oc patch casdeployment "$cas_name" -n "$DEFAULT_NAMESPACE" --type=merge -p '{"spec":{"shutdown":false}}'
    echo -e "${GREEN}✅ Commande de démarrage envoyée. L'opérateur va provisionner le Controller puis les Workers.${NC}"
}

afficher_logs_et_statut() {
    local component_name="$1"
    local search_string="$2"
    
    echo -e "\n${CYAN}=== [ $component_name ] ===${NC}"
    echo -e "${YELLOW}🖥️  Statut du/des Pod(s) :${NC}"
    
    # On isole les pods correspondant à la recherche (ex: sas-cas-operator)
    local pod_list=$(oc get pods -n "$DEFAULT_NAMESPACE" --no-headers 2>/dev/null | grep "$search_string" | awk '{print $1}')
    
    if [ -z "$pod_list" ]; then
        echo -e "${RED}Aucun pod trouvé pour $component_name ($search_string).${NC}"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        read -p "Appuyez sur Entrée pour revenir au menu..."
        return
    fi
    
    # Affichage propre du tableau du/des pods ciblés
    oc get pods -n "$DEFAULT_NAMESPACE" 2>/dev/null | head -n 1
    oc get pods -n "$DEFAULT_NAMESPACE" 2>/dev/null | grep "$search_string"
    
    # On prend le premier pod pour les logs
    local first_pod=$(echo "$pod_list" | head -n 1)
    
    # Extraction dynamique du conteneur principal pour éviter les erreurs "a container name must be specified" (sidecars)
    local container_name=$(oc get pod "$first_pod" -n "$DEFAULT_NAMESPACE" -o jsonpath='{.spec.containers[0].name}' 2>/dev/null)
    
    local c_opt=""
    if [ -n "$container_name" ]; then
        c_opt="-c $container_name"
    fi
    
    echo -e "\n${YELLOW}📄 Logs récents de $first_pod (10 dernières lignes) :${NC}"
    oc logs "$first_pod" $c_opt -n "$DEFAULT_NAMESPACE" --tail=10
    
    echo -e "\n${CYAN}--------------------------------------------------------------${NC}"
    read -p "👉 Voulez-vous suivre les logs en temps réel (tail -f) ? (o/N) : " voir_logs
    if [[ "$voir_logs" =~ ^[oO]$ ]]; then
        echo -e "${YELLOW}⏳ Affichage des logs en temps réel (Appuyez sur Ctrl+C pour quitter)...${NC}"
        oc logs -f "$first_pod" $c_opt -n "$DEFAULT_NAMESPACE" --tail=50
    fi
}

choisir_et_agir() {
    local action_msg="$1"
    local func_to_call="$2"
    
    echo -e "\n${CYAN}Sélectionnez le serveur CAS pour l'action : ${YELLOW}$action_msg${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    for i in "${!CAS_SERVERS[@]}"; do
        echo -e " ${BOLD}$((i+1)))${NC} ${CAS_SERVERS[$i]}"
    done
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${RED}a)${NC} Annuler"
    echo ""
    read -p "👉 Votre choix : " srv_choice
    
    if [[ "$srv_choice" == "a" || "$srv_choice" == "A" ]]; then
        return
    fi
    
    if [[ "$srv_choice" =~ ^[0-9]+$ ]] && [ "$srv_choice" -ge 1 ] && [ "$srv_choice" -le "${#CAS_SERVERS[@]}" ]; then
        local target_cas="${CAS_SERVERS[$((srv_choice-1))]}"
        $func_to_call "$target_cas"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        read -p "Appuyez sur Entrée pour continuer..."
    else
        echo -e "${RED}Choix invalide.${NC}"
        sleep 1
    fi
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================
while true; do
    clear
    echo -e "${CYAN}=== [ GESTION & STATUT DU SERVEUR CAS ] ===${NC}"
    echo -e "Namespace : ${YELLOW}$DEFAULT_NAMESPACE${NC}\n"
    
    echo -e " ${BOLD}1)${NC} 📊 Statut Global (Ressources, Pods, Déploiements)"
    echo -e " ${BOLD}2)${NC} 🔎 Statut détaillé d'un serveur CAS spécifique"
    echo -e " ${BOLD}3)${NC} 🚀 Démarrer un serveur CAS (Start)"
    echo -e " ${BOLD}4)${NC} 🛑 Arrêter un serveur CAS (Stop)"
    echo -e " ${BOLD}5)${NC} 🛠️  Opérateur CAS (sas-cas-operator) : Statut & Logs"
    echo -e " ${BOLD}6)${NC} ⚙️  Contrôleur CAS (sas-cas-control) : Statut & Logs"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${RED}q)${NC} Retour au menu principal"
    echo ""
    read -p "👉 Votre choix : " main_choice

    case "$main_choice" in
        1) afficher_statut_global ;;
        2) choisir_et_agir "Statut détaillé" afficher_statut_cas ;;
        3) choisir_et_agir "Démarrer (Start)" demarrer_cas ;;
        4) choisir_et_agir "Arrêter (Stop)" arreter_cas ;;
        5) afficher_logs_et_statut "Opérateur CAS" "sas-cas-operator" ;;
        6) afficher_logs_et_statut "Contrôleur CAS" "sas-cas-control" ;;
        q|Q) break ;;
        *) echo -e "${RED}Choix invalide.${NC}" ; sleep 1 ;;
    esac
done
