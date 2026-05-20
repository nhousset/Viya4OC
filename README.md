
# Viya4OC (Viya OC ToolBox)

🔧 **Viya4OC** est une collection d’outils en ligne de commande (scripts **PowerShell** lancés via des **.bat**) pour interagir rapidement avec un environnement **SAS Viya 4** hébergé sur **Red Hat OpenShift**.  
L’objectif est de simplifier les commandes répétitives `oc`/`kubectl` et d’accélérer les actions courantes (inventaire pods, consultation des logs, `describe`, contrôles de base).  

> Public cible : administrateurs / exploitants Viya 4 sur OpenShift, support N2/N3, équipes DevOps.

---

## ✨ Fonctionnalités

- **Lister rapidement les pods SAS Viya** du namespace cible (vue “running”, vue complète, etc.).
- **Mode interactif** pour sélectionner un pod sans retaper son nom.
- **Accès rapide aux logs** (`oc logs`) d’un pod.
- **Description détaillée** (`oc describe`) pour diagnostic (événements, mounts, probes, restarts…).
- **Scripts “check”** orientés validation et premières analyses (pods / compute).

---

## 🧱 Pré-requis

### Poste client
- **Windows** (recommandé, car les lanceurs sont des `.bat`).
- **PowerShell 5.1+** (ou PowerShell 7+, selon ton environnement).
- **OpenShift CLI (`oc.exe`)** présent dans le `PATH`.
  - Téléchargeable depuis la console OpenShift : `?` → **Command Line Tools**.
- Accès au cluster OpenShift et droits sur le namespace Viya.

### Accès cluster
- Être **authentifié** sur le cluster OpenShift (ex: `oc login ...`).
- Connaître le **namespace** (projet OpenShift) où tourne Viya 4.

> ℹ️ Rappel : dans Viya sur Kubernetes/OpenShift, la majorité du troubleshooting commence par l’observation des **pods**, de leur statut, des événements et des logs.  
> Voir les commandes de base `get/describe/logs/top` dans la doc SAS.  

---

## 📦 Installation

### Option A — via Git
```bash
git clone https://github.com/nhousset/Viya4OC.git
cd Viya4OC
