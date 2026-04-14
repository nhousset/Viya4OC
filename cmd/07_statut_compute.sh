#!/bin/bash
# TITLE: Statut du Serveur Compute (Sessions & Jobs)

echo -e "\n=== [STATUT DU SOUS-SYSTÈME COMPUTE] ==="

# 1. Vérification du service Launcher (Le chef d'orchestre)
echo "🚀 État des pods Launcher (Le service qui instancie les sessions) :"
oc get pods -n "$DEFAULT_NAMESPACE" -l app=sas-launcher

# 2. Vérification des sessions Compute actives
echo -e "\n💻 Sessions Compute actives (Utilisateurs dans SAS Studio, etc.) :"
# Viya 4 utilise des labels spécifiques pour marquer les pods créés par le launcher
COMPUTE_PODS=$(oc get pods -n "$DEFAULT_NAMESPACE" -l launcher.sas.com/job-type=compute-server --no-headers 2>/dev/null)

if [ -z "$COMPUTE_PODS" ]; then
    echo "✅ Aucune session compute active pour le moment."
else
    # On affiche les pods avec leurs statuts et l'âge
    oc get pods -n "$DEFAULT_NAMESPACE" -l launcher.sas.com/job-type=compute-server
    
    # 3. Consommation des ressources de ces sessions
    echo -e "\n📈 Consommation CPU/RAM des sessions actives :"
    oc adm top pods -n "$DEFAULT_NAMESPACE" -l launcher.sas.com/job-type=compute-server 2>/dev/null || echo "Métriques indisponibles."
fi

# 4. Vérification des Batchs (Jobs planifiés)
echo -e "\n⚙️  Jobs Batch en cours d'exécution :"
BATCH_PODS=$(oc get pods -n "$DEFAULT_NAMESPACE" -l launcher.sas.com/job-type=sas-programming-environment --no-headers 2>/dev/null)

if [ -z "$BATCH_PODS" ]; then
    echo "Aucun job batch actif."
else
    oc get pods -n "$DEFAULT_NAMESPACE" -l launcher.sas.com/job-type=sas-programming-environment
fi

# 5. Recherche des crashs récents (très fréquent sur le compute)
echo -e "\n⚠️  Pods Compute en échec (Erreurs, OOMKilled, Evicted) :"
# On cherche les pods compute qui ont échoué (souvent à cause d'un manque de RAM)
FAILED_COMPUTE=$(oc get pods -n "$DEFAULT_NAMESPACE" -l launcher.sas.com/job-type=compute-server --field-selector=status.phase=Failed --no-headers 2>/dev/null)

if [ -z "$FAILED_COMPUTE" ]; then
    echo "✅ Aucun crash de session compute détecté."
else
    oc get pods -n "$DEFAULT_NAMESPACE" -l launcher.sas.com/job-type=compute-server --field-selector=status.phase=Failed
    echo "💡 Astuce : Utilisez la commande d'extraction des logs pour analyser ces échecs."
fi
