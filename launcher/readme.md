# Viya4OC Launcher 🚀

`launcher` est un utilitaire léger écrit en Go, conçu pour s'exécuter en arrière-plan (daemon) et orchestrer l'exécution régulière de commandes shell ou de scripts (idéal pour la surveillance continue de SAS Viya 4 ou des tâches récurrentes).

## 🌟 Fonctionnalités

*   **Exécution en arrière-plan (Daemon)** : Tourne de manière autonome et invisible en tâche de fond.
*   **Planification flexible** : Configuration complète des tâches via un simple fichier `config.json`.
*   **Fenêtres de tir personnalisables** : Permet de définir des intervalles d'exécution et des plages horaires spécifiques pour chaque commande.
*   **Gestion simplifiée** : Commandes intégrées pour démarrer (`start`), arrêter (`stop`) et vérifier le statut (`status`) du service.
*   **Fichier de journalisation** : Redirection des sorties vers un fichier log personnalisé.

## ⚙️ Configuration (`config.json`)

Le comportement du launcher est entièrement dicté par le fichier `config.json` situé dans le même répertoire. Il contient un tableau de tâches (`tasks`).

**Exemple de configuration :**
```json
{
  "tasks": [
    {
      "name": "HealthCheck",
      "command": "echo 'Health check OK' && sleep 1",
      "time_window": "00:00-23:59",
      "interval_sec": 5
    },
    {
      "name": "DailyTask",
      "command": "/chemin/vers/script.sh",
      "time_window": "02:00-04:00",
      "interval_sec": 3600
    }
  ]
}
```

*   **`name`** : Le nom identifiant votre tâche (utile pour les logs).
*   **`command`** : La commande bash ou le chemin du script à exécuter.
*   **`time_window`** : La plage horaire durant laquelle la tâche est autorisée à s'exécuter (au format `HH:MM-HH:MM`).
*   **`interval_sec`** : Le délai d'attente (en secondes) entre chaque exécution consécutive.

## 🚀 Utilisation

### Syntaxe générale

```bash
launcher <start|stop|status> [--log <path>]
```

### Démarrer le Launcher

Pour lancer le daemon en arrière-plan. Il va créer un fichier `launcher.pid` pour garder une trace de son processus :
```bash
./launcher start --log /tmp/launcher.log
```

### Vérifier le statut

Pour vérifier si le service est actuellement en cours d'exécution :
```bash
./launcher status
```

### Arrêter le Launcher

Pour stopper proprement le daemon (utilise le PID enregistré) :
```bash
./launcher stop
```


```bash
cd launcher
go build -o launcher main.go
```
