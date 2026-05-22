package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Task struct maps to the JSON configuration for each shell script.
type Task struct {
	Name        string `json:"name"`
	Command     string `json:"command"`
	TimeWindow  string `json:"time_window"`
	IntervalSec int    `json:"interval_sec"`
}

// Config struct maps to the root of the JSON configuration.
type Config struct {
	Tasks []Task `json:"tasks"`
}

const pidFile = "launcher.pid"
const configFile = "config.json"

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	action := os.Args[1]

	// Parse flags for optional logging
	flags := flag.NewFlagSet("launcher", flag.ExitOnError)
	logPath := flags.String("log", "launcher.log", "Path to the log file")
	flags.Parse(os.Args[2:])

	switch action {
	case "start":
		startDaemon(*logPath, os.Args[2:])
	case "stop":
		stopDaemon()
	case "status":
		statusDaemon()
	case "run":
		// Internal command executed by "start" to run in background
		runScheduler(*logPath)
	default:
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: launcher <start|stop|status> [--log <path>]")
	fmt.Println("Example: launcher start --log /tmp/launcher.log")
}

// startDaemon spawns the process in the background.
func startDaemon(logPath string, passedArgs []string) {
	if isRunning() {
		fmt.Println("Launcher is already running.")
		return
	}

	// Prepare the command to re-execute itself with the "run" argument
	args := append([]string{"run"}, passedArgs...)
	cmd := exec.Command(os.Args[0], args...)
	
	// Detach the process from the current terminal
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}

	if err := cmd.Start(); err != nil {
		fmt.Printf("Failed to start daemon: %v\n", err)
		os.Exit(1)
	}

	// Write PID to file
	err := os.WriteFile(pidFile, []byte(strconv.Itoa(cmd.Process.Pid)), 0644)
	if err != nil {
		fmt.Printf("Failed to write PID file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Launcher started successfully (PID: %d). Logging to %s\n", cmd.Process.Pid, logPath)
}

// stopDaemon reads the PID file and sends a SIGTERM signal.
func stopDaemon() {
	pid, err := getPID()
	if err != nil {
		fmt.Println("Launcher is not running (no PID file found).")
		return
	}

	process, err := os.FindProcess(pid)
	if err != nil {
		fmt.Printf("Failed to find process: %v\n", err)
		return
	}

	// Send termination signal
	err = process.Signal(syscall.SIGTERM)
	if err != nil && err.Error() != "os: process already finished" {
		fmt.Printf("Failed to stop process: %v\n", err)
		return
	}

	os.Remove(pidFile)
	fmt.Println("Launcher stopped.")
}

// statusDaemon checks if the process is currently running.
func statusDaemon() {
	pid, err := getPID()
	if err != nil {
		fmt.Println("Status: STOPPED (No PID file)")
		return
	}

	process, err := os.FindProcess(pid)
	if err != nil {
		fmt.Println("Status: STOPPED (Process not found)")
		return
	}

	// Sending signal 0 checks for process existence without killing it
	err = process.Signal(syscall.Signal(0))
	if err == nil {
		fmt.Printf("Status: RUNNING (PID: %d)\n", pid)
	} else {
		fmt.Println("Status: STOPPED (Process is dead but PID file exists)")
		os.Remove(pidFile)
	}
}

// runScheduler is the main loop running in the background.
func runScheduler(logPath string) {
	setupLogger(logPath)
	log.Println("=== Launcher Started ===")

	jsonFile, err := os.ReadFile(configFile)
	if err != nil {
		log.Fatalf("Error reading config file: %v", err)
	}

	var config Config
	err = json.Unmarshal(jsonFile, &config)
	if err != nil {
		log.Fatalf("Error parsing JSON: %v", err)
	}

	log.Printf("Loaded %d tasks from config.", len(config.Tasks))

	// Channel to keep the main goroutine alive
	done := make(chan bool)

	// Launch each task in its own Goroutine
	for _, task := range config.Tasks {
		go scheduleTask(task)
	}

	<-done // Block forever
}

// scheduleTask handles the execution loop for a single task.
func scheduleTask(task Task) {
	log.Printf("[Task: %s] Initialized. Window: %s, Interval: %ds", task.Name, task.TimeWindow, task.IntervalSec)
	ticker := time.NewTicker(time.Duration(task.IntervalSec) * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		if isWithinTimeWindow(task.TimeWindow) {
			log.Printf("[Task: %s] Triggering command: %s", task.Name, task.Command)
			executeCommand(task.Name, task.Command)
		} else {
			log.Printf("[Task: %s] Skipped (Outside of time window: %s)", task.Name, task.TimeWindow)
		}
	}
}

// executeCommand runs the shell string and logs the output.
func executeCommand(taskName, command string) {
	cmd := exec.Command("sh", "-c", command)
	output, err := cmd.CombinedOutput()
	
	if err != nil {
		log.Printf("[Task: %s] ERROR executing: %v | Output: %s", taskName, err, strings.TrimSpace(string(output)))
		return
	}
	
	log.Printf("[Task: %s] SUCCESS | Output: %s", taskName, strings.TrimSpace(string(output)))
}

// isWithinTimeWindow checks if current time is within "HH:MM-HH:MM".
func isWithinTimeWindow(window string) bool {
	parts := strings.Split(window, "-")
	if len(parts) != 2 {
		return true // If format is wrong, default to true
	}

	now := time.Now().Format("15:04")
	start := parts[0]
	end := parts[1]

	if start <= end {
		return now >= start && now <= end
	}
	return now >= start || now <= end
}

// Helpers

func setupLogger(logPath string) {
	file, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		fmt.Printf("Failed to open log file: %v\n", err)
		os.Exit(1)
	}
	multiWriter := io.MultiWriter(file)
	
	log.SetOutput(multiWriter)
	log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds | log.Lshortfile)
}

func getPID() (int, error) {
	data, err := os.ReadFile(pidFile)
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(strings.TrimSpace(string(data)))
}

func isRunning() bool {
	pid, err := getPID()
	if err != nil {
		return false
	}
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	return process.Signal(syscall.Signal(0)) == nil
}
