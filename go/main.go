package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"golang.org/x/term"
)

var (
	RED    = "\033[0;31m"
	GREEN  = "\033[0;32m"
	YELLOW = "\033[1;33m"
	BLUE   = "\033[0;34m"
	PURPLE = "\033[0;35m"
	CYAN   = "\033[0;36m"
	BOLD   = "\033[1m"
	NC     = "\033[0m"

	ScriptDir  string
	ConfigFile string
	CmdDir     string

	configCache map[string]string
)

func init() {
	exePath, err := os.Executable()
	if err != nil {
		exePath = os.Args[0]
	}
	ScriptDir = filepath.Dir(exePath)
	ConfigFile = filepath.Join(ScriptDir, "config.env")
	CmdDir = filepath.Join(ScriptDir, "cmd")
	configCache = make(map[string]string)
}

func loadConfig() {
	data, err := os.ReadFile(ConfigFile)
	if err != nil {
		return
	}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "export ") {
			line = strings.TrimPrefix(line, "export ")
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				key := parts[0]
				val := parts[1]
				val = strings.Trim(val, "\"")
				val = strings.Trim(val, "'")
				configCache[key] = val
				os.Setenv(key, val)
			}
		}
	}
}

func saveToConfig(key, value string) {
	configCache[key] = value
	os.Setenv(key, value)

	var outLines []string
	if data, err := os.ReadFile(ConfigFile); err == nil {
		lines := strings.Split(string(data), "\n")
		for _, line := range lines {
			trimmed := strings.TrimSpace(line)
			if strings.HasPrefix(trimmed, "export "+key+"=") {
				continue
			}
			if len(trimmed) > 0 {
				outLines = append(outLines, line)
			}
		}
	}
	outLines = append(outLines, fmt.Sprintf("export %s=\"%s\"", key, value))

	os.WriteFile(ConfigFile, []byte(strings.Join(outLines, "\n")+"\n"), 0600)
}

func prompt(msg string) string {
	fmt.Print(msg)
	reader := bufio.NewReader(os.Stdin)
	text, _ := reader.ReadString('\n')
	return strings.TrimSpace(text)
}

func promptPassword(msg string) string {
	fmt.Print(msg)
	bytePassword, _ := term.ReadPassword(int(os.Stdin.Fd()))
	fmt.Println()
	return strings.TrimSpace(string(bytePassword))
}

func checkAndPromptVars() {
	if configCache["TOKEN_URL"] == "" {
		fmt.Printf("%sInitialisation de la configuration...%s\n", YELLOW, NC)
		fmt.Println("Pour vous connecter au cluster, vous aurez besoin d'aller chercher un token sur l'interface web OpenShift.")
		url := prompt(" URL pour répér le token OpenShift (ou 's' pour ignorer/skip) : ")
		if strings.ToLower(url) == "s" {
			saveToConfig("TOKEN_URL", "skip")
		} else {
			saveToConfig("TOKEN_URL", url)
		}
	}
	if configCache["SERVER_URL"] == "" {
		url := prompt(" URL du cluster OpenShift : ")
		saveToConfig("SERVER_URL", url)
	}
	if configCache["TOKEN"] == "" {
		tokenUrl := configCache["TOKEN_URL"]
		if tokenUrl != "" && tokenUrl != "skip" {
			fmt.Printf("\n%s %s\n", PURPLE, NC)
			fmt.Printf("%s  %s Bonjour ! Il nous faut un jeton (token) OpenShift.%s\n", PURPLE, YELLOW, NC)
			fmt.Printf("%s  %sVous pouvez en gérer un tout neuf en un clic via ce lien :%s\n", PURPLE, NC, NC)
			fmt.Printf("%s   %s%s%s%s\n", PURPLE, BOLD, CYAN, tokenUrl, NC)
			fmt.Printf("%s %s\n\n", PURPLE, NC)
		}
		token := promptPassword(" Token de connexion OpenShift : ")
		saveToConfig("TOKEN", token)
	}
	if configCache["DEFAULT_NAMESPACE"] == "" {
		ns := prompt(" Namespace SAS Viya [sas-viya] : ")
		if ns == "" {
			ns = "sas-viya"
		}
		saveToConfig("DEFAULT_NAMESPACE", ns)
	}
	if configCache["OC_BIN_PATH"] == "" {
		ocPath := prompt(" Chemin COMPLET du binaire oc : ")
		saveToConfig("OC_BIN_PATH", ocPath)
	}

	if ocPath := configCache["OC_BIN_PATH"]; ocPath != "" {
		if _, err := os.Stat(ocPath); err == nil {
			dir := filepath.Dir(ocPath)
			pathEnv := os.Getenv("PATH")
			os.Setenv("PATH", dir+string(os.PathListSeparator)+pathEnv)
		}
	}
	if configCache["INSECURE_SKIP_TLS_VERIFY"] == "" {
		saveToConfig("INSECURE_SKIP_TLS_VERIFY", "true")
	}
	if configCache["AUDIT_OUT_DIR"] == "" {
		saveToConfig("AUDIT_OUT_DIR", filepath.Join(ScriptDir, "rapports_audit"))
	}
}

func doLogin() {
	checkAndPromptVars()

	ns := configCache["DEFAULT_NAMESPACE"]

	cmd := exec.Command("oc", "whoami")
	if err := cmd.Run(); err == nil {
		exec.Command("oc", "project", ns).Run()
		return
	}

	serverUrl := configCache["SERVER_URL"]
	fmt.Printf("%s Connexion às...%s\n", CYAN, serverUrl, NC)

	loginArgs := []string{"login", serverUrl, "--token=" + configCache["TOKEN"]}
	if configCache["INSECURE_SKIP_TLS_VERIFY"] == "true" {
		loginArgs = append(loginArgs, "--insecure-skip-tls-verify=true")
	}

	cmd = exec.Command("oc", loginArgs...)
	if err := cmd.Run(); err == nil {
		fmt.Printf("%s Connexion résie.%s\n", GREEN, NC)
		exec.Command("oc", "project", ns).Run()
	} else {
		fmt.Printf("%s Token invalide ou expirés\n", RED, NC)

		tokenUrl := configCache["TOKEN_URL"]
		fmt.Printf("\n%s %s\n", PURPLE, NC)
		fmt.Printf("%s  %s Oups ! Votre token est invalide ou a expirés\n", PURPLE, YELLOW, NC)
		if tokenUrl != "" && tokenUrl != "skip" {
			fmt.Printf("%s  %sPas de panique, allez répér un nouveau token juste ici :%s\n", PURPLE, NC, NC)
			fmt.Printf("%s   %s%s%s%s\n", PURPLE, BOLD, CYAN, tokenUrl, NC)
		} else {
			fmt.Printf("%s  %sConnectez-vous à'interface web OpenShift pour en gérer un nouveau.%s\n", PURPLE, NC, NC)
		}
		fmt.Printf("%s %s\n\n", PURPLE, NC)

		newToken := promptPassword(" Nouveau Token : ")
		if newToken == "" {
			os.Exit(1)
		}
		saveToConfig("TOKEN", newToken)

		loginArgs[2] = "--token=" + configCache["TOKEN"]
		cmd = exec.Command("oc", loginArgs...)
		if err := cmd.Run(); err == nil {
			fmt.Printf("%s Connexion résie.%s\n", GREEN, NC)
			exec.Command("oc", "project", ns).Run()
		} else {
			fmt.Printf("%s Éhec critique.%s\n", RED, NC)
			os.Exit(1)
		}
	}
}

func showHelp() {
	fmt.Printf("%s", CYAN)
	fmt.Println("  ____       _      ____   __     __  ___  __   __     _       _  _     ___   ____   ____  ")
	fmt.Println(" / ___|     / \\    / ___|  \\ \\   / / |_ _| \\ \\ / /    / \\     | || |   / _ \\ |  _ \\ / ___| ")
	fmt.Println(" \\___ \\    / _ \\   \\___ \\   \\ \\ / /   | |   \\ V /    / _ \\    | || |_ | | | || |_) |\\___ \\ ")
	fmt.Println("  ___) |  / ___ \\   ___) |   \\ V /    | |    | |    / ___ \\   |__   _|| |_| ||  __/  ___) |")
	fmt.Println(" |____/  /_/   \\_\\ |____/     \\_/    |___|   |_|   /_/   \\_\\     |_|   \\___/ |_|    |____/ ")
	fmt.Printf("%s", NC)
	fmt.Printf("%s%s============================================================================================%s\n", BOLD, BLUE, NC)
	fmt.Printf("%s   SAS VIYA 4 OPS - Aide & Utilisation%s\n", BOLD, NC)
	fmt.Println("   (c) Nicolas Housset | https://github.com/nhousset/Viya4OC/ | https://nicolas-housset.fr/")
	fmt.Printf("%s%s============================================================================================%s\n\n", BOLD, BLUE, NC)

	fmt.Printf("%sUsage:%s\n", BOLD, NC)
	fmt.Println("  ./viya [OPTIONS]")
	fmt.Println()
	fmt.Printf("%sOptions:%s\n", BOLD, NC)
	fmt.Printf("  %s-h, --help%s           Affiche cet éan d'aide.\n", CYAN, NC)
	fmt.Printf("  %s--cmd <script.sh>%s    Exéte directement un script contenu dans le dossier 'cmd'\n", CYAN, NC)
	fmt.Println("                       sans passer par le menu interactif. L'authentification")
	fmt.Println("                       sera véfiéavant le lancement.")
	fmt.Println()
	fmt.Printf("%sExemples:%s\n", BOLD, NC)
	fmt.Printf("  ./viya                        %s# Lance le menu interactif%s\n", CYAN, NC)
	fmt.Printf("  ./viya --cmd check_status.sh  %s# Exéte directement 'check_status.sh'%s\n", CYAN, NC)
	fmt.Println()
}

func clearScreen() {
	var cmd *exec.Cmd
	if strings.Contains(strings.ToLower(os.Getenv("OS")), "windows") {
		cmd = exec.Command("cmd", "/c", "cls")
	} else {
		cmd = exec.Command("clear")
	}
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func getRunningPodsCount(ns string) int {
	cmd := exec.Command("oc", "get", "pods", "-n", ns, "--field-selector=status.phase=Running", "--no-headers")
	out, err := cmd.Output()
	if err != nil {
		return 0
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return 0
	}
	return len(lines)
}

func executeScript(scriptPath string) {
	fmt.Printf("\n%s Lancement : %s%s\n", YELLOW, filepath.Base(scriptPath), NC)
	fmt.Printf("%s--------------------------------------------------------------------------------------------%s\n", BLUE, NC)

	if !strings.Contains(strings.ToLower(os.Getenv("OS")), "windows") {
		os.Chmod(scriptPath, 0755)
	}

	var cmd *exec.Cmd
	if strings.HasSuffix(scriptPath, ".sh") {
		cmd = exec.Command("bash", scriptPath)
	} else {
		cmd = exec.Command(scriptPath)
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Run()
}

func showMenu() {
	doLogin()

	ns := configCache["DEFAULT_NAMESPACE"]
	runningCount := getRunningPodsCount(ns)

	clearScreen()
	fmt.Printf("%s", CYAN)
	fmt.Println("  ____       _      ____   __     __  ___  __   __     _       _  _     ___   ____   ____  ")
	fmt.Println(" / ___|     / \\    / ___|  \\ \\   / / |_ _| \\ \\ / /    / \\     | || |   / _ \\ |  _ \\ / ___| ")
	fmt.Println(" \\___ \\    / _ \\   \\___ \\   \\ \\ / /   | |   \\ V /    / _ \\    | || |_ | | | || |_) |\\___ \\ ")
	fmt.Println("  ___) |  / ___ \\   ___) |   \\ V /    | |    | |    / ___ \\   |__   _|| |_| ||  __/  ___) |")
	fmt.Println(" |____/  /_/   \\_\\ |____/     \\_/    |___|   |_|   /_/   \\_\\     |_|   \\___/ |_|    |____/ ")
	fmt.Printf("%s", NC)
	fmt.Printf("%s============================================================================================%s\n", BLUE, NC)
	fmt.Printf("%s   SAS VIYA 4 OPS - Console d'Administration%s\n", BOLD, NC)
	fmt.Println("   (c) Nicolas Housset | https://github.com/nhousset/Viya4OC/ | https://nicolas-housset.fr/")
	fmt.Printf("%s============================================================================================%s\n", BLUE, NC)
	fmt.Printf(" Namespace : %s%s%s\n", CYAN, ns, NC)
	fmt.Printf(" Statut    : %sConnecté | %sPods actifs: %d%s\n", GREEN, NC, YELLOW, runningCount, NC)
	fmt.Printf("%s--------------------------------------------------------------------------------------------%s\n", BLUE, NC)

	os.MkdirAll(CmdDir, 0755)
	files, err := os.ReadDir(CmdDir)

	var scripts []string
	for _, f := range files {
		if !f.IsDir() && strings.HasSuffix(f.Name(), ".sh") {
			scripts = append(scripts, f.Name())
		}
	}

	if err != nil || len(scripts) == 0 {
		fmt.Printf("%s   (Aucun plugin trouvés\n", RED, NC)
	} else {
		for i, script := range scripts {
			title := script
			content, err := os.ReadFile(filepath.Join(CmdDir, script))
			if err == nil {
				lines := strings.Split(string(content), "\n")
				for _, l := range lines {
					if strings.HasPrefix(l, "# TITLE:") {
						title = strings.TrimSpace(strings.TrimPrefix(l, "# TITLE:"))
						break
					}
				}
			}
			fmt.Printf(" %s%s%d)%s %s\n", BOLD, CYAN, i+1, NC, title)
		}
	}

	fmt.Printf("%s--------------------------------------------------------------------------------------------%s\n", BLUE, NC)
	fmt.Printf(" %sq)%s Quitter & Logout      %sx)%s Quitter (Garder session)\n", RED, NC, RED, NC)
	fmt.Printf("%s============================================================================================%s\n", BLUE, NC)

	choice := prompt(" Votre choix ? ")
	switch strings.ToLower(choice) {
	case "q":
		exec.Command("oc", "logout").Run()
		os.Exit(0)
	case "x":
		fmt.Println("Bye.")
		os.Exit(0)
	}

	idx, err := strconv.Atoi(choice)
	if err != nil || idx < 1 || idx > len(scripts) {
		fmt.Printf("%s Choix invalide.%s\n", RED, NC)
		showMenu()
		return
	}

	selectedScript := filepath.Join(CmdDir, scripts[idx-1])
	executeScript(selectedScript)

	fmt.Printf("%s--------------------------------------------------------------------------------------------%s\n", BLUE, NC)
	prompt("Appuyez sur Entrépour revenir au menu...")
	showMenu()
}

func main() {
	loadConfig()

	args := os.Args[1:]
	directCmd := ""

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "-h", "--help":
			showHelp()
			os.Exit(0)
		case "--cmd":
			if i+1 < len(args) {
				directCmd = args[i+1]
				i++
			} else {
				fmt.Printf("%s Erreur : l'argument --cmd néssite le nom d'un script.%s\n", RED, NC)
				fmt.Println("Utilisez --help pour plus d'informations.")
				os.Exit(1)
			}
		default:
			fmt.Printf("%s Option inconnue : %s%s\n", RED, arg, NC)
			fmt.Println("Utilisez --help pour plus d'informations.")
			os.Exit(1)
		}
	}

	if directCmd != "" {
		targetScript := filepath.Join(CmdDir, directCmd)
		if _, err := os.Stat(targetScript); err != nil {
			fmt.Printf("%s Erreur : Le script '%s' est introuvable dans le dossier '%s'.%s\n", RED, directCmd, CmdDir, NC)
			os.Exit(1)
		}

		doLogin()
		executeScript(targetScript)
	} else {
		showMenu()
	}
}

