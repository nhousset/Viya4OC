🚀 Viya4_Adm : Console d'Administration SAS Viya 4 sur OpenShift
Viya4_Adm est un outil interactif en ligne de commande (CLI) développé en Bash, conçu pour simplifier, accélérer et sécuriser l'administration quotidienne d'un environnement SAS Viya 4 déployé sur Red Hat OpenShift.

Plutôt que de saisir manuellement des dizaines de commandes oc, cet outil centralise les opérations de diagnostic, de monitoring et de troubleshooting via une interface menuisée et colorisée.

🌟 Fonctionnalités Principales
Gestion intelligente de la session : Authentification oc login automatisée, conservation de la session, et demande de renouvellement uniquement lorsque le token expire.

Menu Dynamique (Moteur de plugins) : Les scripts ajoutés dans le dossier cmd/ sont automatiquement détectés et ajoutés au menu principal.

Sécurité intégrée : Le fichier de configuration (config.env) contenant le token est généré dynamiquement et restreint en lecture (chmod 600).

Outils interactifs : Capacité à rechercher, filtrer et agir sur les pods (logs, shell, suppression) directement depuis un menu.

🛠️ Prérequis
Pour utiliser cet outil, votre poste de travail (ou bastion) doit disposer de :

Bash (Linux, macOS, ou Git Bash/WSL sur Windows).

Le binaire oc (OpenShift Command Line Interface) installé.

curl, awk, et grep (nativement présents sur la majorité des systèmes UNIX).

Un accès réseau vers l'API du cluster OpenShift cible.

Un compte disposant des droits suffisants sur le namespace SAS Viya (ex: rôle admin ou edit).

📥 Installation & Premier Démarrage
Cloner ou télécharger ce dépôt sur votre machine :

Bash
git clone https://github.com/votre-nom/viya4_adm.git
cd viya4_adm
Rendre le script principal exécutable :

Bash
chmod +x viya.sh
Lancer l'outil :

Bash
./viya.sh
Configuration Initiale (Lazy Loading)
Au premier lancement, le script détectera l'absence du fichier config.env et vous demandera interactivement :

L'URL de l'API OpenShift (ex: https://api.mon-cluster.com:6443).

Votre Token de connexion (la saisie sera masquée).

Le namespace cible (par défaut : sas-viya).

Le chemin complet vers votre binaire oc.

Ces informations seront sauvegardées de manière sécurisée. Lors des prochains lancements, le menu s'affichera instantanément.

🖥️ Utilisation
Le script s'utilise principalement via son menu interactif.

Bash
./viya.sh
(Navigation) : Saisissez simplement le numéro du module que vous souhaitez lancer et appuyez sur Entrée. Appuyez sur q pour vous déconnecter proprement, ou x pour fermer le menu en conservant votre session OpenShift active.

📸 [Insérer ici une capture d'écran du menu principal colorisé affichant le nombre de pods actifs]

🧰 Guide des Plugins (Modules)
Les fonctionnalités sont réparties dans des scripts indépendants situés dans le dossier cmd/. Voici le détail de chaque module :

📊 Audits & Monitoring Global
01_audit_complet.sh : Génère un rapport de santé complet (Noeuds, Pods, Réseau, Limites) et le sauvegarde dans un fichier texte dans le dossier rapports_audit/.

10_top_pods.sh : Affiche instantanément les 10 pods consommant le plus de CPU et les 10 pods consommant le plus de RAM. Indispensable en cas de ralentissement.

08_limites_quotas.sh : Vérifie si votre namespace est bridé par des ResourceQuotas ou si des LimitRanges forcent des restrictions de ressources sur vos pods.

🧠 Moteur SAS & Compute
03_statut_cas.sh : Isole et affiche l'état de santé du moteur In-Memory CAS (Cloud Analytic Services), ses ressources personnalisées (CASDeployment) et sa consommation.

07_statut_compute.sh : Surveille le sous-système Compute. Permet de voir les sessions utilisateurs SAS Studio actives (compute-server), les batchs en cours, et de lister les pods en erreur (ex: plantages liés à des erreurs OOMKilled).

💾 Stockage & Bases de Données
02_audit_stockage.sh : Vérifie l'état des volumes persistants (PVC) et remonte les événements récents liés à des erreurs de montage.

09_pvc_mapping.sh : Très puissant. Cartographie tous les volumes (PVC) et indique précisément par quel(s) pod(s) ils sont utilisés. Met en surbrillance rouge les volumes "Orphelins" (qui consomment de l'espace sans être rattachés à un pod).

05_statut_postgres.sh : Vérifie l'état de l'opérateur CrunchyData et des clusters PostgreSQL internes de Viya.

📸 [Insérer ici une capture d'écran du résultat du PVC Mapping ou du Top Pods]

🌐 Réseau & Infrastructure
11_test_routes.sh : Ne se contente pas de lister les URL (Ingress), mais effectue un ping HTTP/HTTPS automatique sur chaque route pour valider que les interfaces web de Viya répondent correctement (Code 200, 302, 401...).

06_certificats_tls.sh : Liste les certificats gérés par cert-manager et les secrets TLS pour anticiper les expirations.

⚙️ Microservices & Planification
12_statut_deployments.sh : Vérifie les centaines de microservices Viya et met en surbrillance rouge uniquement ceux qui sont en échec ou incomplets (ex: 0/1 READY).

13_statut_cronjobs.sh : Liste les tâches planifiées et vérifie l'état des exécutions récentes (ex: le job de sauvegarde nocturne de SAS).

🛠️ Troubleshooting & Actions Interactives
04_logs_erreurs.sh : Trouve automatiquement tous les pods en statut d'erreur (CrashLoopBackOff, Error, etc.) et extrait les 20 dernières lignes de logs pour chacun.

14_gestion_pods.sh : L'explorateur interactif. Ce module permet de :

Lister tous les pods.

Filtrer la liste en direct (ex: taper "logon" pour ne voir que les pods logon).

Sélectionner un pod via son numéro.

Ouvrir un sous-menu pour : Voir les logs, faire un tail -f, lancer un describe, ouvrir un terminal interactif (rsh) à l'intérieur du pod, ou le supprimer/redémarrer en toute sécurité.

📸 [Insérer ici deux captures d'écran côte à côte : 1. L'explorateur avec un filtre de recherche. 2. Le sous-menu d'action d'un pod]

👨‍💻 Guide pour les Développeurs (Ajouter un plugin)
L'architecture est modulaire. Pour ajouter une nouvelle fonctionnalité à l'outil, vous n'avez pas besoin de modifier le script principal viya.sh.

Créez un nouveau fichier Bash dans le dossier cmd/ (ex: 15_mon_script.sh).

Ajoutez ce tag en haut de votre script : # TITLE: Le nom qui apparaîtra dans le menu.

Rendez-le exécutable : chmod +x cmd/15_mon_script.sh.

Exemple de modèle (cmd/15_hello.sh) :

Bash
#!/bin/bash
# TITLE: Dire Bonjour au Namespace

echo -e "\n=== [ TEST PLUGIN ] ==="
echo "Le namespace actuel est : $DEFAULT_NAMESPACE"
echo "Les rapports sont sauvés dans : $AUDIT_OUT_DIR"

oc get pods -n "$DEFAULT_NAMESPACE" | wc -l
Le menu principal détectera automatiquement le fichier et l'ajoutera à la liste !
