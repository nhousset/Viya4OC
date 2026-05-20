
# Viya4OC

🔧 **Viya4OC** est un outil en ligne de commande écrit en **Bash** pour faciliter l’administration et le troubleshooting d’une plateforme **SAS Viya 4** déployée sur **OpenShift (Kubernetes)**.

Il fournit un **menu interactif** et des scripts prêts à l’emploi pour exécuter rapidement les commandes `oc` essentielles (audit, état des pods, CAS, réseau, etc.).

---

## ✨ Fonctionnalités

- ✅ Menu interactif central (via `viya.sh`)
- ✅ Gestion de configuration persistée (`config.env`)
- ✅ Connexion simplifiée au cluster OpenShift
- ✅ Audit complet de la plateforme :
  - Nodes
  - Pods
  - Réseau (services / routes)
  - Quotas et limites
- ✅ Diagnostic du moteur **CAS**
- ✅ Exploitation directe des commandes `oc`

---

## 🧱 Pré-requis

- Linux / macOS / WSL (Bash requis)
- OpenShift CLI (`oc`)
- Accès à un cluster OpenShift avec SAS Viya 4 déployé
- Token d’accès OpenShift

---

## 📦 Installation

```bash
git clone https://github.com/nhousset/Viya4OC.git
cd Viya4OC
chmod +x viya.sh
