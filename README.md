# Viya4OC 🚀

Un orchestrateur d'administration interactif en ligne de commande pour SAS Viya 4 sur OpenShift. 

Cet outil simplifie grandement la gestion, la surveillance et le dépannage de votre environnement SAS Viya 4 en regroupant les commandes OpenShift (`oc`) les plus utiles dans une interface interactive et conviviale.

## 🌟 Fonctionnalités

*   **Authentification simplifiée** : Gestion facile du token OpenShift et de l'URL du cluster.
*   **Surveillance et Ressources** :
    *   Vérification de l'état des Pods, Deployments et CronJobs.
    *   Consultation des statistiques de consommation (Top Pods).
    *   Vérification des limites et quotas du cluster.
*   **Gestion du stockage** : Mapping et vérification des PVC (Persistent Volume Claims).
*   **Administration SAS Viya** :
    *   Gestion des serveurs CAS (Démarrage, arrêt, gestion des sessions).
    *   Test de la connectivité et des routes.
    *   Consultation en direct des logs critiques (tail).
*   **Multi-plateforme** : L'outil est compilé en Go et disponible nativement pour Windows et Linux.

## 🚀 Installation & Utilisation

L'outil est prêt à l'emploi grâce aux exécutables précompilés disponibles dans le dossier `bin`.

### Prérequis

*   Le binaire client OpenShift (`oc`) doit être installé sur votre machine.
*   Un accès valide à un cluster OpenShift hébergeant SAS Viya 4.

### Lancement rapide

1.  Clonez ce dépôt ou téléchargez l'exécutable correspondant à votre système depuis le dossier `bin/`.
2.  Lancez l'application dans votre terminal :

**Sur Linux / macOS :**
```bash
./bin/viya
```

**Sur Windows :**
```powershell
.\bin\viya.exe
```

3.  **Configuration initiale** : Lors du tout premier lancement, l'outil vous guidera pour configurer vos accès :
    *   URL de l'interface OpenShift (pour récupérer le token).
    *   URL de l'API du cluster OpenShift.
    *   Token de connexion (un lien direct vous sera fourni).
    *   Namespace de SAS Viya (par défaut : `sas-viya`).
    *   Chemin vers votre exécutable `oc`.

> [!NOTE]
> Ces informations seront sauvegardées localement (dans un fichier `config.env`) pour ne pas avoir à les ressaisir lors de vos prochaines sessions.

## 📂 Structure du projet

*   `bin/` : Contient les exécutables prêts à l'emploi (`viya` pour Linux, `viya.exe` pour Windows).
*   `go/` : Code source de l'application principale écrite en Go (`main.go`).
*   `src/` : Code source de l'ancienne version pure bash (`viya.sh`).
*   `cmd/` : Scripts spécialisés exécutés par l'orchestrateur (gestion des pods, quotas, logs, etc.).
*   `tools/` : Outils et scripts annexes.

## 🛠️ Compilation depuis les sources (Optionnel)

Si vous souhaitez modifier le code et recompiler l'outil vous-même (nécessite [Go](https://go.dev/)) :

```bash
# Se placer dans le dossier Go
cd go

# Compiler pour Linux
go build -o ../bin/viya main.go

# Compiler pour Windows
GOOS=windows GOARCH=amd64 go build -o ../bin/viya.exe main.go
```
