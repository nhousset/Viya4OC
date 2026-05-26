#!/bin/bash
# TITLE: Boîte à Outils d'Administration des Sauvegardes SAS Viya 4

# Ce script est modulaire et conçu pour être placé exclusivement dans le dossier 'cmd/'.
# Il s'exécute de manière autonome en héritant des variables globales de oc.sh ($OC_CMD, $NAMESPACE).
# Toutes les commandes et filtres de labels sont directement issus de la documentation officielle SAS Viya Platform.

# Génération d'une chaîne d'horodatage pour les exécutions ad-hoc uniques
get_timestamp() {
    date +%Y%m%d-%H%M%S
}

# Fonction principale pour afficher le menu interactif complet
manage_backups_loop() {
    while true; do
        clear
        echo "================================================================================"
        echo "   📦 LOGICIEL D'OUTILLAGE ET DE GESTION DES SAUVEGARDES SAS VIYA 4"
        echo "   Namespace courant : ${NAMESPACE:-'Par défaut'} | Commande : $OC_CMD"
        echo "================================================================================"
        echo "  --- SURVEILLANCE & INFRASTRUCTURE ---"
        echo "  1) Vérifier les volumes de stockage des sauvegardes (PVC & Rôles)"
        echo "  2) Lister l'historique global de TOUTES les sauvegardes exécutées"
        echo "  3) Filtrer les sauvegardes incluant PostgreSQL (INCLUDE_POSTGRES=true)"
        echo "  4) Filtrer les sauvegardes excluant PostgreSQL (INCLUDE_POSTGRES=false)"
        echo "  5) Consulter l'état des planifications automatiques (CronJobs)"
        echo ""
        echo "  --- RECHERCHE & DIAGNOSTIC CIBLÉ ---"
        echo "  6) Obtenir le statut précis d'une sauvegarde via son ID (Backup ID)"
        echo "  7) Inspecter les détails et les types de sources de données d'un Backup"
        echo "  8) Suivre l'avancement en temps réel / Temps restant estimé (Progress)"
        echo "  9) Consulter les logs d'un job de sauvegarde spécifique"
        echo ""
        echo "  --- DÉCLENCHEMENT DE SAUVEGARDES (AD-HOC) ---"
        echo "  10) Lancer une sauvegarde Ad-Hoc Standard (Full)"
        echo "  11) Lancer une sauvegarde Ad-Hoc Incrémentale (Nécessite une Full préalable)"
        echo "  12) Lancer une sauvegarde Ad-Hoc Totale Forcée (All Sources avec PostgreSQL)"
        echo ""
        echo "  --- CONFIGURATION AVANCÉE & DÉPANNAGE ---"
        echo "  13) Consulter le CronJob de purge automatique (sas-backup-purge-job)"
        echo "  14) [Dépannage] Désactiver la validation proactive de l'espace disque (Patch)"
        echo "  15) [Dépannage] Réactiver la validation proactive de l'espace disque (Patch)"
        echo ""
        echo "  r) Retour au menu d'administration principal"
        echo "================================================================================"
        read -p "👉 Sélectionnez une action (1-15) ou 'r' pour quitter : " MENU_CHOICE
        echo ""

        case "$MENU_CHOICE" in
            1)
                echo "🔍 Analyse des PersistentVolumeClaims liés au rôle de stockage..."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD get pvc -l "sas.com/backup-role=storage"
                ;;
            2)
                echo "📜 Liste exhaustive de l'historique des sauvegardes (Trié par date de début)..."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD get jobs -l "sas.com/backup-job-type in (scheduled-backup, scheduled-backup-incremental)" \
                    -L "sas.com/sas-backup-id,sas.com/backup-job-type,sas.com/sas-backup-job-status,sas.com/sas-backup-persistence-status,sas.com/sas-backup-include-postgres" \
                    --sort-by=.status.startTime
                ;;
            3)
                echo "📜 Sauvegardes contenant la base PostgreSQL (INCLUDE_POSTGRES=true)..."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD get jobs -l "sas.com/backup-job-type in (scheduled-backup, scheduled-backup-incremental),sas.com/sas-backup-include-postgres=true" \
                    -L "sas.com/sas-backup-id,sas.com/backup-job-type,sas.com/sas-backup-job-status,sas.com/sas-backup-persistence-status" \
                    --sort-by=.status.startTime
                ;;
            4)
                echo "📜 Sauvegardes excluant la base PostgreSQL (INCLUDE_POSTGRES=false)..."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD get jobs -l "sas.com/backup-job-type in (scheduled-backup, scheduled-backup-incremental),sas.com/sas-backup-include-postgres=false" \
                    -L "sas.com/sas-backup-id,sas.com/backup-job-type,sas.com/sas-backup-job-status,sas.com/sas-backup-persistence-status" \
                    --sort-by=.status.startTime
                ;;
            5)
                echo "⏰ Vérification des configurations horaires et statuts des CronJobs..."
                echo "--------------------------------------------------------------------------------"
                echo "--- Sauvegardes Automatiques Standard (Weekly Full) ---"
                $OC_CMD get cronjobs -l "sas.com/backup-job-type=scheduled-backup"
                echo ""
                echo "--- Sauvegardes Automatiques Incrémentales (Daily) ---"
                $OC_CMD get cronjobs -l "sas.com/backup-job-type=scheduled-backup-incremental"
                ;;
            6)
                read -p "📝 Entrez le Backup ID (Ex: 20260512-061344F) : " BKP_ID
                if [ ! -z "$BKP_ID" ]; then
                    echo "🔍 Recherche du statut du Job associé au Backup ID : $BKP_ID..."
                    echo "--------------------------------------------------------------------------------"
                    $OC_CMD get jobs -l "sas.com/sas-backup-id=$BKP_ID" \
                        -L "sas.com/sas-backup-id,sas.com/backup-job-type,sas.com/sas-backup-job-status,sas.com/sas-backup-persistence-status"
                else
                    echo "❌ Backup ID invalide ou vide."
                fi
                ;;
            7)
                read -p "📝 Entrez le Backup ID à inspecter : " BKP_ID
                if [ ! -z "$BKP_ID" ]; then
                    echo "🔍 Extraction des métadonnées détaillées (Description Kubernetes)..."
                    echo "--------------------------------------------------------------------------------"
                    $OC_CMD describe jobs -l "sas.com/sas-backup-id=$BKP_ID"
                    echo ""
                    echo "📊 Liste des types de sources de données incluses dans cette sauvegarde :"
                    echo "--------------------------------------------------------------------------------"
                    $OC_CMD get jobs -l "sas.com/sas-backup-id=$BKP_ID" -L "sas.com/sas-backup-datasource-types"
                else
                    echo "❌ Backup ID invalide ou vide."
                fi
                ;;
            8)
                echo "⏳ Calcul de l'avancement et temps restant estimé (BACKUP-REMAINING-TIME)..."
                echo "ℹ️  Note : Cette information affiche 'initializing-3min', 'Estimation-Timed-Out', 'SHUTTING-DOWN' ou le délai restant."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD get jobs -l "sas.com/backup-job-type in (scheduled-backup)" -L "sas.com/backup-remaining-time" --sort-by=.status.startTime
                ;;
            9)
                read -p "📝 Entrez le nom exact du Job ou une partie du nom (Ex: adhoc-backup) : " NAME_FILTER
                if [ ! -z "$NAME_FILTER" ]; then
                    echo "🔍 Recherche du pod actif ou récent associé au job..."
                    POD_NAME=$($OC_CMD get pods --no-headers -o custom-columns=":metadata.name" | grep "$NAME_FILTER" | head -n 1)
                    if [ ! -z "$POD_NAME" ]; then
                        echo "📋 Extraction des logs pour le conteneur 'sas-backup-job' de $POD_NAME..."
                        echo "--------------------------------------------------------------------------------"
                        $OC_CMD logs "$POD_NAME" -c sas-backup-job
                    else
                        echo "❌ Aucun pod correspondant trouvé pour le filtre : $NAME_FILTER"
                    fi
                else
                    echo "❌ Filtre vide."
                fi
                ;;
            10)
                TS=$(get_timestamp)
                ADHOC_NAME="adhoc-full-$TS"
                echo "🚀 Déclenchement d'un Job de sauvegarde standard à partir du CronJob hebdomadaire..."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD create job --from=cronjob/sas-scheduled-backup-job "$ADHOC_NAME"
                echo "💡 Suivez l'avancement avec l'option (8) ou les logs avec l'option (9) en utilisant le nom : $ADHOC_NAME"
                ;;
            11)
                TS=$(get_timestamp)
                ADHOC_NAME="adhoc-incr-$TS"
                echo "🚀 Déclenchement d'une sauvegarde incrémentale ad-hoc..."
                echo "⚠️  Attention : Requis 'INCLUDE_POSTGRES=false' et une sauvegarde complète préexistante."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD create job --from=cronjob/sas-scheduled-backup-incr-job "$ADHOC_NAME"
                echo "💡 Suivez le statut via l'option (2)."
                ;;
            12)
                TS=$(get_timestamp)
                ADHOC_NAME="adhoc-all-sources-$TS"
                echo "🚀 Lancement d'une sauvegarde totale forcée de TOUTES les sources (PostgreSQL inclus)..."
                echo "ℹ️  Cette commande outrepasse temporairement le paramètre INCLUDE_POSTGRES=false (Recommandé PRA/DR)."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD create job --from=cronjob/sas-scheduled-backup-all-sources "$ADHOC_NAME"
                echo "💡 Job créé sous le nom : $ADHOC_NAME"
                ;;
            13)
                echo "🧹 Récupération de la description de la configuration du cycle de purge automatique..."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD describe cronjob sas-backup-purge-job
                ;;
            14)
                echo "🛠️  Application du correctif (Patch) pour désactiver la validation des ressources d'espace disque..."
                echo "⚠️  À utiliser si le calcul de la taille disponible de l'agent lève une erreur aberrante ou négative."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD patch cm sas-backup-job-parameters --type json -p '[{"op": "replace", "path": "/data/DISABLE_VALIDATION", "value":"true"}]'
                ;;
            15)
                echo "🛠️  Restauration du comportement par défaut : Réactivation de la vérification de l'espace disque..."
                echo "--------------------------------------------------------------------------------"
                $OC_CMD patch cm sas-backup-job-parameters --type json -p '[{"op": "replace", "path": "/data/DISABLE_VALIDATION", "value":"false"}]'
                ;;
            r|R)
                echo "🔙 Retour au menu d'administration oc.sh."
                return 0
                ;;
            *)
                echo "❌ Choix d'action non valide."
                ;;
        esac

        echo ""
        read -p "Appuyez sur [Entrée] pour revenir au menu de gestion des sauvegardes..."
    done
}

# Lancement automatique de la boucle lors de l'appel du script par oc.sh
manage_backups_loop
