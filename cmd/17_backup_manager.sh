#!/bin/bash
# TITLE: Gestion des Sauvegardes & PRA (Backups Viya)

# ==============================================================================
# Fichier : 05_backup_manager.sh
# Description : Boîte à outils d'administration des sauvegardes SAS Viya 4
# ==============================================================================

# Définition des couleurs (redéfinies ici car exécuté dans un sous-shell)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Génération d'une chaîne d'horodatage pour les exécutions ad-hoc uniques
get_timestamp() {
    date +%Y%m%d-%H%M%S
}

# Fonction principale pour afficher le menu interactif complet
manage_backups_loop() {
    while true; do
        clear
        echo -e "${BLUE}============================================================================================${NC}"
        echo -e "${BOLD}   📦 OUTILLAGE ET GESTION DES SAUVEGARDES SAS VIYA 4${NC}"
        echo -e "   Namespace courant : ${CYAN}${DEFAULT_NAMESPACE:-'Par défaut'}${NC} | Commande : ${CYAN}${OC_CMD:-oc}${NC}"
        echo -e "${BLUE}============================================================================================${NC}"
        
        echo -e "  ${YELLOW}--- SURVEILLANCE & INFRASTRUCTURE ---${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Vérifier les volumes de stockage des sauvegardes (PVC & Rôles)"
        echo -e "  ${BOLD}${CYAN}2)${NC} Lister l'historique global de TOUTES les sauvegardes exécutées"
        echo -e "  ${BOLD}${CYAN}3)${NC} Filtrer les sauvegardes incluant PostgreSQL (INCLUDE_POSTGRES=true)"
        echo -e "  ${BOLD}${CYAN}4)${NC} Filtrer les sauvegardes excluant PostgreSQL (INCLUDE_POSTGRES=false)"
        echo -e "  ${BOLD}${CYAN}5)${NC} Consulter l'état des planifications automatiques (CronJobs)"
        echo ""
        echo -e "  ${YELLOW}--- RECHERCHE & DIAGNOSTIC CIBLÉ ---${NC}"
        echo -e "  ${BOLD}${CYAN}6)${NC} Obtenir le statut précis d'une sauvegarde via son ID (Backup ID)"
        echo -e "  ${BOLD}${CYAN}7)${NC} Inspecter les détails et les types de sources d'un Backup"
        echo -e "  ${BOLD}${CYAN}8)${NC} Suivre l'avancement en temps réel / Temps restant estimé (Progress)"
        echo -e "  ${BOLD}${CYAN}9)${NC} Consulter les logs d'un job de sauvegarde spécifique"
        echo ""
        echo -e "  ${YELLOW}--- DÉCLENCHEMENT DE SAUVEGARDES (AD-HOC) ---${NC}"
        echo -e "  ${BOLD}${CYAN}10)${NC} Lancer une sauvegarde Ad-Hoc Standard (Full)"
        echo -e "  ${BOLD}${CYAN}11)${NC} Lancer une sauvegarde Ad-Hoc Incrémentale (Nécessite une Full préalable)"
        echo -e "  ${BOLD}${CYAN}12)${NC} Lancer une sauvegarde Totale Forcée (All Sources avec PostgreSQL)"
        echo ""
        echo -e "  ${YELLOW}--- CONFIGURATION AVANCÉE & DÉPANNAGE ---${NC}"
        echo -e "  ${BOLD}${CYAN}13)${NC} Consulter le CronJob de purge automatique (sas-backup-purge-job)"
        echo -e "  ${BOLD}${CYAN}14)${NC} ${PURPLE}[Dépannage]${NC} Désactiver la validation d'espace disque (Patch DISABLE_VALIDATION=true)"
        echo -e "  ${BOLD}${CYAN}15)${NC} ${PURPLE}[Dépannage]${NC} Réactiver la validation d'espace disque (Patch DISABLE_VALIDATION=false)"
        echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
        echo -e "  ${RED}r)${NC} Retour au menu d'administration principal"
        echo -e "${BLUE}============================================================================================${NC}"
        read -p "👉 Sélectionnez une action (1-15) ou 'r' pour quitter : " MENU_CHOICE
        echo ""

        case "$MENU_CHOICE" in
            1)
                echo -e "${CYAN}🔍 [Doc p.5, 59, 61] Analyse des PersistentVolumeClaims liés au rôle de stockage...${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} get pvc -l "sas.com/backup-role=storage"
                ;;
            2)
                echo -e "${CYAN}📜 [Doc p.18] Liste exhaustive de l'historique des sauvegardes (Trié par date de début)...${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} get jobs -l "sas.com/backup-job-type in (scheduled-backup, scheduled-backup-incremental)" \
                    -L "sas.com/sas-backup-id,sas.com/backup-job-type,sas.com/sas-backup-job-status,sas.com/sas-backup-persistence-status,sas.com/sas-backup-include-postgres" \
                    --sort-by=.status.startTime
                ;;
            3)
                echo -e "${CYAN}📜 [Doc p.18] Sauvegardes contenant la base PostgreSQL (INCLUDE_POSTGRES=true)...${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} get jobs -l "sas.com/backup-job-type in (scheduled-backup, scheduled-backup-incremental),sas.com/sas-backup-include-postgres=true" \
                    -L "sas.com/sas-backup-id,sas.com/backup-job-type,sas.com/sas-backup-job-status,sas.com/sas-backup-persistence-status" \
                    --sort-by=.status.startTime
                ;;
            4)
                echo -e "${CYAN}📜 [Doc p.18] Sauvegardes excluant la base PostgreSQL (INCLUDE_POSTGRES=false)...${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} get jobs -l "sas.com/backup-job-type in (scheduled-backup, scheduled-backup-incremental),sas.com/sas-backup-include-postgres=false" \
                    -L "sas.com/sas-backup-id,sas.com/backup-job-type,sas.com/sas-backup-job-status,sas.com/sas-backup-persistence-status" \
                    --sort-by=.status.startTime
                ;;
            5)
                echo -e "${CYAN}⏰ [Doc p.24] Vérification des configurations horaires et statuts des CronJobs...${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                echo -e "${YELLOW}--- Sauvegardes Automatiques Standard (Weekly Full) ---${NC}"
                ${OC_CMD:-oc} get cronjobs -l "sas.com/backup-job-type=scheduled-backup"
                echo ""
                echo -e "${YELLOW}--- Sauvegardes Automatiques Incrémentales (Daily) ---${NC}"
                ${OC_CMD:-oc} get cronjobs -l "sas.com/backup-job-type=scheduled-backup-incremental"
                ;;
            6)
                read -p "📝 Entrez le Backup ID (Ex: 20260512-061344F) : " BKP_ID
                if [ ! -z "$BKP_ID" ]; then
                    echo -e "\n${CYAN}🔍 [Doc p.19] Recherche du statut du Job associé au Backup ID : $BKP_ID...${NC}"
                    echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                    ${OC_CMD:-oc} get jobs -l "sas.com/sas-backup-id=$BKP_ID" \
                        -L "sas.com/sas-backup-id,sas.com/backup-job-type,sas.com/sas-backup-job-status,sas.com/sas-backup-persistence-status"
                else
                    echo -e "${RED}❌ Backup ID invalide ou vide.${NC}"
                fi
                ;;
            7)
                read -p "📝 Entrez le Backup ID à inspecter : " BKP_ID
                if [ ! -z "$BKP_ID" ]; then
                    echo -e "\n${CYAN}🔍 [Doc p.19] Extraction des métadonnées détaillées (Description Kubernetes)...${NC}"
                    echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                    ${OC_CMD:-oc} describe jobs -l "sas.com/sas-backup-id=$BKP_ID"
                    echo ""
                    echo -e "${CYAN}📊 [Doc p.19] Liste des types de sources de données incluses dans cette sauvegarde :${NC}"
                    echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                    ${OC_CMD:-oc} get jobs -l "sas.com/sas-backup-id=$BKP_ID" -L "sas.com/sas-backup-datasource-types"
                else
                    echo -e "${RED}❌ Backup ID invalide ou vide.${NC}"
                fi
                ;;
            8)
                echo -e "${CYAN}⏳ [Doc p.76] Calcul de l'avancement et temps restant estimé (BACKUP-REMAINING-TIME)...${NC}"
                echo -e "${PURPLE}ℹ️  Note : Affiche 'initializing-3min', 'Estimation-Timed-Out', 'SHUTTING-DOWN' ou le délai restant.${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} get jobs -l "sas.com/backup-job-type in (scheduled-backup)" -L "sas.com/backup-remaining-time" --sort-by=.status.startTime
                ;;
            9)
                read -p "📝 Entrez le nom exact du Job ou une partie du nom (Ex: adhoc-backup) : " NAME_FILTER
                if [ ! -z "$NAME_FILTER" ]; then
                    echo -e "\n${CYAN}🔍 Recherche du pod actif ou récent associé au job...${NC}"
                    POD_NAME=$(${OC_CMD:-oc} get pods --no-headers -o custom-columns=":metadata.name" | grep "$NAME_FILTER" | head -n 1)
                    if [ ! -z "$POD_NAME" ]; then
                        echo -e "${GREEN}📋 Extraction des logs pour le conteneur 'sas-backup-job' de $POD_NAME...${NC}"
                        echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                        ${OC_CMD:-oc} logs "$POD_NAME" -c sas-backup-job
                    else
                        echo -e "${RED}❌ Aucun pod correspondant trouvé pour le filtre : $NAME_FILTER${NC}"
                    fi
                else
                    echo -e "${RED}❌ Filtre vide.${NC}"
                fi
                ;;
            10)
                TS=$(get_timestamp)
                ADHOC_NAME="adhoc-full-$TS"
                echo -e "${CYAN}🚀 [Doc p.17] Déclenchement d'un Job de sauvegarde standard (CronJob hebdomadaire)...${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} create job --from=cronjob/sas-scheduled-backup-job "$ADHOC_NAME"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ Job '$ADHOC_NAME' créé avec succès.${NC}"
                    echo -e "${PURPLE}💡 Suivez l'avancement avec l'option (8) ou les logs avec l'option (9).${NC}"
                fi
                ;;
            11)
                TS=$(get_timestamp)
                ADHOC_NAME="adhoc-incr-$TS"
                echo -e "${CYAN}🚀 [Doc p.17, 362] Déclenchement d'une sauvegarde incrémentale ad-hoc...${NC}"
                echo -e "${YELLOW}⚠️  Attention : Requis 'INCLUDE_POSTGRES=false' et une sauvegarde complète préexistante.${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} create job --from=cronjob/sas-scheduled-backup-incr-job "$ADHOC_NAME"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ Job '$ADHOC_NAME' créé avec succès.${NC}"
                    echo -e "${PURPLE}💡 Suivez le statut via l'option (2).${NC}"
                fi
                ;;
            12)
                TS=$(get_timestamp)
                ADHOC_NAME="adhoc-all-sources-$TS"
                echo -e "${CYAN}🚀 [Doc p.18, 373] Lancement d'une sauvegarde totale forcée de TOUTES les sources...${NC}"
                echo -e "${YELLOW}ℹ️  Cette commande outrepasse temporairement le paramètre INCLUDE_POSTGRES=false (Recommandé PRA/DR).${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} create job --from=cronjob/sas-scheduled-backup-all-sources "$ADHOC_NAME"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ Job '$ADHOC_NAME' créé avec succès.${NC}"
                fi
                ;;
            13)
                echo -e "${CYAN}🧹 [Doc p.46] Récupération de la description de la configuration du cycle de purge automatique...${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} describe cronjob sas-backup-purge-job
                ;;
            14)
                echo -e "${YELLOW}🛠️  [Doc p.85] Application du correctif (Patch) pour désactiver la validation des ressources d'espace disque...${NC}"
                echo -e "${PURPLE}⚠️  À utiliser si le calcul de la taille disponible lève une erreur aberrante ou négative.${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} patch cm sas-backup-job-parameters --type json -p '[{"op": "replace", "path": "/data/DISABLE_VALIDATION", "value":"true"}]'
                if [ $? -eq 0 ]; then echo -e "${GREEN}✅ Correctif appliqué.${NC}"; fi
                ;;
            15)
                echo -e "${YELLOW}🛠️  [Doc p.85] Restauration du comportement par défaut : Réactivation de la vérification de l'espace disque...${NC}"
                echo -e "${BLUE}--------------------------------------------------------------------------------------------${NC}"
                ${OC_CMD:-oc} patch cm sas-backup-job-parameters --type json -p '[{"op": "replace", "path": "/data/DISABLE_VALIDATION", "value":"false"}]'
                if [ $? -eq 0 ]; then echo -e "${GREEN}✅ Comportement par défaut restauré.${NC}"; fi
                ;;
            r|R)
                echo -e "${GREEN}🔙 Retour au menu d'administration oc.sh.${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ Choix d'action non valide.${NC}"
                ;;
        esac

        echo ""
        read -p "Appuyez sur [Entrée] pour revenir au menu de gestion des sauvegardes..."
    done
}

# Lancement automatique de la boucle lors de l'appel du script par oc.sh
manage_backups_loop
