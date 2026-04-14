#!/bin/bash
# TITLE: Cartographie des volumes (PVC) et Pods associés

echo -e "\n=== [CARTOGRAPHIE STOCKAGE : PVC <-> PODS] ==="
echo "Analyse en cours sur le namespace : $DEFAULT_NAMESPACE..."
echo "Cela peut prendre quelques secondes selon la taille du cluster."

# 1. On récupère tous les PVC (Nom, Statut, Capacité)
PVC_LIST=$(oc get pvc -n "$DEFAULT_NAMESPACE" --no-headers -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,SIZE:.status.capacity.storage 2>/dev/null)

if [ -z "$PVC_LIST" ]; then
    echo "✅ Aucun PVC (Persistent Volume Claim) trouvé dans ce namespace."
    exit 0
fi

# 2. On récupère une cartographie brute de tous les pods et leurs volumes
# Format généré : NomDuPod:pvc1,pvc2,pvc3,
POD_MAPPING=$(oc get pods -n "$DEFAULT_NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{":"}{range .spec.volumes[*]}{.persistentVolumeClaim.claimName}{","}{end}{"\n"}{end}' 2>/dev/null)

echo -e "\n-------------------------------------------------------------------------------------------------------"
printf "%-45s | %-8s | %-8s | %s\n" "NOM DU PVC" "STATUT" "TAILLE" "UTILISÉ PAR LE(S) POD(S)"
echo "-------------------------------------------------------------------------------------------------------"

ORPHANS=0

# 3. On boucle sur chaque PVC pour trouver qui l'utilise
while read -r pvc_name status size; do
    [ -z "$pvc_name" ] && continue
    
    attached_pods=""
    
    # On cherche le nom du PVC dans notre cartographie des pods
    for line in $POD_MAPPING; do
        pod_name="${line%%:*}"
        pvcs="${line#*:}"
        
        # On vérifie si la liste des PVC du pod contient exactement notre PVC
        if [[ ",$pvcs" == *",$pvc_name,"* ]]; then
            # On ajoute le pod à la liste s'il y a un match
            if [ -z "$attached_pods" ]; then
                attached_pods="$pod_name"
            else
                attached_pods="$attached_pods, $pod_name"
            fi
        fi
    done
    
    # Formatage de l'affichage si le PVC n'est rattaché à aucun pod
    if [ -z "$attached_pods" ]; then
        if [ "$status" == "Bound" ]; then
            attached_pods="⚠️  <ORPHELIN - Non utilisé>"
            ((ORPHANS++))
        else
            attached_pods="⏳ <En attente d'attachement>"
        fi
    fi
    
    # Affichage de la ligne formatée
    printf "%-45s | %-8s | %-8s | %s\n" "$pvc_name" "$status" "$size" "$attached_pods"

done <<< "$PVC_LIST"

echo "-------------------------------------------------------------------------------------------------------"

# 4. Résumé
if [ $ORPHANS -gt 0 ]; then
    echo -e "\n💡 Attention : $ORPHANS PVC(s) au statut 'Bound' ne sont rattachés à aucun pod actif."
    echo "Il s'agit souvent de reliquats d'anciens traitements (SAS Compute/CAS) qui consomment de l'espace inutilement."
else
    echo -e "\n✅ Tous les PVC provisionnés sont activement utilisés par des pods."
fi
