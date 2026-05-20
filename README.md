
# 🚀 Viya4OC

🔧 **Viya4OC** est un outil en ligne de commande en **Bash** permettant d’administrer et diagnostiquer une plateforme **SAS Viya 4** déployée sur **OpenShift (Kubernetes)**.

Il s’appuie sur des scripts modulaires et un orchestrateur (`viya.sh`) pour simplifier l’utilisation des commandes `oc` et accélérer les opérations de troubleshooting.

---

## 🎯 Objectif

Faciliter le travail des administrateurs et des équipes support en proposant :

- ✅ Un menu CLI interactif
- ✅ Des audits automatisés
- ✅ Des raccourcis vers les commandes OpenShift
- ✅ Des diagnostics rapides (pods, CAS, DB, TLS)

---

## ⚙️ Fonctionnalités principales

- 🔐 Gestion de configuration persistée (`config.env`)
- 🔌 Connexion simplifiée à OpenShift
- 📊 Audit global de la plateforme
- ⚙️ Suivi du moteur CAS
- ⚠️ Détection des pods en erreur + logs
- 🗄️ Vérification PostgreSQL (CrunchyData)
- 🔐 Contrôle des certificats TLS

---

## 🧱 Pré-requis

- Bash (Linux / macOS / WSL)
- OpenShift CLI (`oc`)
- Accès à un cluster OpenShift avec SAS Viya 4
- Token OpenShift

---

## 📦 Installation

```bash
git clone https://github.com/nhousset/Viya4OC.git
cd Viya4OC
chmod +x viya.sh
``
