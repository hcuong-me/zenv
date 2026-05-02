// Package shell handles shell configuration and hook installation
package shell

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/hcuong-me/zenv/internal/storage"
)

// ZshrcManager handles operations on ~/.zshrc
type ZshrcManager struct {
	Path string
}

// NewZshrcManager creates a new ZshrcManager with the default path
func NewZshrcManager() *ZshrcManager {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		homeDir = ""
	}
	return &ZshrcManager{
		Path: filepath.Join(homeDir, ".zshrc"),
	}
}

// IsHookInstalled checks if the zenv hook is already in ~/.zshrc
func (zm *ZshrcManager) IsHookInstalled() bool {
	content, err := os.ReadFile(zm.Path)
	if err != nil {
		return false
	}
	return strings.Contains(string(content), "# --- zenv safe display start ---")
}

// InstallHook adds the zenv hook to ~/.zshrc
func (zm *ZshrcManager) InstallHook() error {
	// Check if zshrc exists
	if _, err := os.Stat(zm.Path); err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("~/.zshrc not found. Please create it first: touch ~/.zshrc")
		}
		return fmt.Errorf("cannot access ~/.zshrc: %w", err)
	}

	// Read existing content
	content, err := os.ReadFile(zm.Path)
	if err != nil {
		return fmt.Errorf("failed to read ~/.zshrc: %w", err)
	}

	// Check if hook already exists
	if strings.Contains(string(content), "# --- zenv safe display start ---") {
		return nil // Already installed
	}

	// Backup zshrc first
	backupPath := getZenvBackupPath(zm.Path, "hook")
	if err := os.WriteFile(backupPath, content, 0644); err != nil {
		return fmt.Errorf("failed to create backup: %w", err)
	}

	// Append hook
	hook := getHookContent()
	newContent := string(content)
	if !strings.HasSuffix(newContent, "\n") {
		newContent += "\n"
	}
	newContent += "\n" + hook + "\n"

	if err := os.WriteFile(zm.Path, []byte(newContent), 0644); err != nil {
		return fmt.Errorf("failed to write ~/.zshrc: %w", err)
	}

	return nil
}

// GetBackupPath returns the path to the latest backup file
func (zm *ZshrcManager) GetBackupPath() string {
	return getZenvBackupPath(zm.Path, "hook")
}

// RestoreBackup restores the zshrc from backup
func (zm *ZshrcManager) RestoreBackup() error {
	backupPath := zm.GetBackupPath()
	content, err := os.ReadFile(backupPath)
	if err != nil {
		return fmt.Errorf("failed to read backup: %w", err)
	}
	if err := os.WriteFile(zm.Path, content, 0644); err != nil {
		return fmt.Errorf("failed to restore backup: %w", err)
	}
	return nil
}

// getHookContent returns the shell hook that masks env vars from ~/.zshenv
func getHookContent() string {
	return `# --- zenv safe display start ---
# 1. Extract keys from .zshenv to build the masking pattern
export _ZENV_KEYS=$(sed -n 's/^export \([^=]*\)=.*/\1/p' "$HOME/.zshenv" | tr '\n' '|' | sed 's/|$//')

# 2. Source the actual values so they are available in RAM
[ -f "$HOME/.zshenv" ] && . "$HOME/.zshenv"

# 3. Security Masker: Redact values when listing environment variables
_zenv_masker() {
    if [ -n "$_ZENV_KEYS" ]; then
        # Matches keys found in .zshenv and hides their values
        sed -E "/^($_ZENV_KEYS)=/s/=.*/=********/"
    else
        cat
    fi
}

# Override display commands
env() { command env "$@" | _zenv_masker; }
printenv() { command printenv "$@" | _zenv_masker; }
# --- zenv safe display end ---`
}

// CheckZsh returns true if current shell is zsh
func CheckZsh() bool {
	shell := os.Getenv("SHELL")
	return strings.Contains(shell, "zsh")
}

// UnsetEnv removes an environment variable from the current session
func UnsetEnv(key string) error {
	return os.Unsetenv(key)
}

// SourceZshenv sources the ~/.zshenv file in the current shell session
func SourceZshenv() error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	zshenvPath := filepath.Join(homeDir, ".zshenv")

	content, err := os.ReadFile(zshenvPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	// Parse and set each export line
	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "export ") {
			parts := strings.SplitN(line[7:], "=", 2)
			if len(parts) == 2 {
				key := parts[0]
				value := strings.Trim(parts[1], `"`)
				if err := os.Setenv(key, value); err != nil {
					return fmt.Errorf("failed to set %s: %w", key, err)
				}
			}
		}
	}

	return nil
}

// ParseExportsFromZshrc reads ~/.zshrc and returns env vars outside zenv section
func ParseExportsFromZshrc(path string) ([]storage.EnvVar, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer func() { _ = file.Close() }()

	var vars []storage.EnvVar
	scanner := bufio.NewScanner(file)
	inZenvSection := false

	// Regex for export lines: export KEY="value" or export KEY='value' or export KEY=value
	exportRegex := regexp.MustCompile(`^\s*export\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$`)

	for scanner.Scan() {
		line := scanner.Text()

		// Check for zenv section markers
		if strings.Contains(line, "# --- zenv safe display start ---") {
			inZenvSection = true
			continue
		}
		if strings.Contains(line, "# --- zenv safe display end ---") {
			inZenvSection = false
			continue
		}

		// Skip lines inside zenv section
		if inZenvSection {
			continue
		}

		// Parse export lines
		if matches := exportRegex.FindStringSubmatch(line); matches != nil {
			key := matches[1]
			// Skip excluded variables (system variables should not be migrated)
			if shouldExcludeVariable(key) {
				continue
			}
			value := extractValue(matches[2])
			vars = append(vars, storage.EnvVar{
				Key:   key,
				Value: value,
			})
		}
	}

	return vars, scanner.Err()
}

// extractValue extracts the value from export line, handling quotes
func extractValue(raw string) string {
	raw = strings.TrimSpace(raw)

	// Remove trailing comments
	if idx := strings.Index(raw, " #"); idx != -1 {
		raw = raw[:idx]
	}

	// Handle double quotes: "value"
	if strings.HasPrefix(raw, `"`) && strings.HasSuffix(raw, `"`) && len(raw) > 1 {
		return raw[1 : len(raw)-1]
	}

	// Handle single quotes: 'value'
	if strings.HasPrefix(raw, `'`) && strings.HasSuffix(raw, `'`) && len(raw) > 1 {
		return raw[1 : len(raw)-1]
	}

	return raw
}

// excludedPatterns contains keywords that identify variables to exclude from migration
// Matches exact names, prefixes, or suffixes depending on the pattern
var excludedPatterns = []string{
	// System PATH variables
	"PATH",
}

// shouldExcludeVariable checks if a key should be excluded from migration
// based on exact match, suffix match, or prefix match with excludedPatterns
func shouldExcludeVariable(key string) bool {
	upperKey := strings.ToUpper(key)

	for _, pattern := range excludedPatterns {
		upperPattern := strings.ToUpper(pattern)

		// Exact match
		if upperKey == upperPattern {
			return true
		}

		// Suffix match: *_PATTERN
		if strings.HasSuffix(upperKey, "_"+upperPattern) {
			return true
		}

		// Prefix match: PATTERN_*
		if strings.HasPrefix(upperKey, upperPattern+"_") {
			return true
		}
	}

	// Special case: any variable ending with _PATH
	if strings.HasSuffix(upperKey, "_PATH") {
		return true
	}

	return false
}

// RemoveExportsFromZshrc removes export lines from ~/.zshrc and creates backup
func RemoveExportsFromZshrc(path string, keysToRemove []string, backupPath string) error {
	// Read original content
	content, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read ~/.zshrc: %w", err)
	}

	// Create backup
	if err := os.WriteFile(backupPath, content, 0644); err != nil {
		return fmt.Errorf("failed to create backup: %w", err)
	}

	// Build set of keys to remove
	removeSet := make(map[string]bool)
	for _, key := range keysToRemove {
		removeSet[key] = true
	}

	// Parse and filter lines
	exportRegex := regexp.MustCompile(`^\s*export\s+([A-Za-z_][A-Za-z0-9_]*)\s*=.*$`)
	lines := strings.Split(string(content), "\n")
	var newLines []string

	for _, line := range lines {
		// Check if this is an export line we should remove
		if matches := exportRegex.FindStringSubmatch(line); matches != nil {
			key := matches[1]
			if removeSet[key] {
				continue // Skip this line
			}
		}
		newLines = append(newLines, line)
	}

	// Write back
	newContent := strings.Join(newLines, "\n")
	if err := os.WriteFile(path, []byte(newContent), 0644); err != nil {
		return fmt.Errorf("failed to write ~/.zshrc: %w", err)
	}

	return nil
}

// getZenvBackupPath returns a backup path in ~/.zenv/backups directory
func getZenvBackupPath(basePath, backupType string) string {
	filename := filepath.Base(basePath)

	homeDir, err := os.UserHomeDir()
	if err != nil {
		homeDir = ""
	}
	backupDir := filepath.Join(homeDir, ".zenv", "backups")

	// Ensure directory exists
	_ = os.MkdirAll(backupDir, 0755)

	return filepath.Join(backupDir, fmt.Sprintf("%s.%s.backup", filename, backupType))
}

// GetBackupPathWithTimestamp returns a backup path with timestamp in ~/.zenv/backups
func GetBackupPathWithTimestamp(basePath string) string {
	// Get filename from basePath (e.g., ".zshrc" from "/home/user/.zshrc")
	filename := filepath.Base(basePath)

	// Create .zenv/backups directory
	homeDir, err := os.UserHomeDir()
	if err != nil {
		homeDir = ""
	}
	backupDir := filepath.Join(homeDir, ".zenv", "backups")

	// Ensure directory exists (create if needed)
	_ = os.MkdirAll(backupDir, 0755)

	timestamp := time.Now().Format("20060102_150405")
	return filepath.Join(backupDir, fmt.Sprintf("%s.migrate.backup.%s", filename, timestamp))
}
