#!/bin/bash
# TITLE: Test de connectivité des Routes (URL Web)

# Couleurs
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}=== [ VÉRIFICATION DES ROUTES (INGRESS) ] ===${NC}"
echo -e "Namespace : ${YELLOW}$DEFAULT_NAMESPACE${NC}\n"

# 1. On récupère la liste brute des routes pour le traitement
# On prend le Nom, l'Hôte (l'URL), et le type de TLS
ROUTES=$(oc get routes -n "$DEFAULT_NAMESPACE" --no-headers -o custom-columns=NAME:.metadata.name,HOST:.spec.host,TLS:.spec.tls.termination 2>/dev/null)

if [ -z "$ROUTES" ]; then
    echo -e "${RED}❌ Aucune route trouvée dans le namespace $DEFAULT_NAMESPACE.${NC}"
    exit 0
fi

# 2. Affichage standard d'OpenShift
echo -e "${YELLOW}🌐 Liste des routes exposées par OpenShift :${NC}"
oc get routes -n "$DEFAULT_NAMESPACE"
echo ""

# 3. Test de connectivité réel
echo -e "${YELLOW}🔍 Test de connectivité (Ping HTTP) sur les hôtes :${NC}"
echo "------------------------------------------------------------------------"
printf "%-35s | %-12s | %s\n" "NOM DE LA ROUTE" "MODE TLS" "RÉPONSE HTTP"
echo "------------------------------------------------------------------------"

# On lit ligne par ligne les routes extraites
while read -r route_name host tls; do
    [ -z "$route_name" ] && continue

    # Construction de l'URL (Viya 4 est presque toujours en HTTPS)
    if [ "$tls" == "<none>" ]; then
        protocol="http://"
    else
        protocol="https://"
    fi

    url="${protocol}${host}"

    # Test avec CURL : 
    # -k : ignore les erreurs de certificat (utile si auto-signé)
    # -s -o /dev/null : mode silencieux, on ne garde pas le corps de la page
    # -w "%{http_code}" : on demande juste le code de retour HTTP
    # --max-time 5 : on n'attend pas plus de 5 secondes pour éviter de bloquer le script
    http_code=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 "$url")

    # Interprétation du code HTTP
    if [ "$http_code" == "000" ]; then
        status="${RED}KO (Injoignable / Timeout)${NC}"
    elif [ "$http_code" == "200" ]; then
        status="${GREEN}200 OK${NC}"
    elif [[ "$http_code" =~ ^3 ]]; then
        status="${GREEN}${http_code} Redirection${NC}"
    elif [[ "$http_code" =~ ^4 ]]; then
        status="${YELLOW}${http_code} Sécurisé (Attendu)${NC}"
    elif [[ "$http_code" =~ ^5 ]]; then
        status="${RED}${http_code} Erreur Serveur (5xx)${NC}"
    else
        status="${NC}${http_code} Statut Inconnu${NC}"
    fi

    # Affichage formaté
    printf "%-35s | %-12s | %b\n" "$route_name" "$tls" "$status"

done <<< "$ROUTES"

echo "------------------------------------------------------------------------"
echo -e "\n💡 ${CYAN}Note pour SAS Viya :${NC}"
echo "   - Un statut en jaune (401/403) ou 302 est généralement normal."
echo "     Cela prouve que l'API est joignable mais nécessite un jeton d'authentification."
echo "   - Un statut 'KO (Injoignable)' indique un problème de DNS ou de LoadBalancer."
