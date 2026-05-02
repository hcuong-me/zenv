// Package storage handles reading and writing environment variables to ~/.zshenv
package storage

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// EnvVar represents an environment variable key-value pair
type EnvVar struct {
	Key   string
	Value string
}

// ZshenvManager handles operations on the ~/.zshenv file
type ZshenvManager struct {
	Path string
}

// NewZshenvManager creates a new ZshenvManager with the default path
func NewZshenvManager() *ZshenvManager {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		homeDir = ""
	}
	return &ZshenvManager{
		Path: filepath.Join(homeDir, ".zshenv"),
	}
}

// Set adds or updates an environment variable in ~/.zshenv
func (zm *ZshenvManager) Set(key, value string) error {
	key = strings.ToUpper(key)

	// Read existing content
	content, err := zm.readFile()
	if err != nil {
		return err
	}

	// Pattern to match existing export line
	pattern := regexp.MustCompile(fmt.Sprintf(`(?m)^export %s=".*"$`, regexp.QuoteMeta(key)))
	newLine := fmt.Sprintf(`export %s="%s"`, key, escapeValue(value))

	if pattern.MatchString(content) {
		// Update existing line
		content = pattern.ReplaceAllString(content, newLine)
	} else {
		// Append new line
		if len(content) > 0 && !strings.HasSuffix(content, "\n") {
			content += "\n"
		}
		content += newLine + "\n"
	}

	// Write back with atomic operation (write to temp then rename)
	if err := zm.atomicWrite(content); err != nil {
		return err
	}

	// Ensure permissions
	return zm.EnsurePermissions()
}

// Remove deletes an environment variable from ~/.zshenv
func (zm *ZshenvManager) Remove(key string) error {
	key = strings.ToUpper(key)

	content, err := zm.readFile()
	if err != nil {
		return err
	}

	// Pattern to match the export line
	pattern := regexp.MustCompile(fmt.Sprintf(`(?m)^export %s=".*"\n?`, regexp.QuoteMeta(key)))

	if !pattern.MatchString(content) {
		return fmt.Errorf("environment variable %s not found", key)
	}

	content = pattern.ReplaceAllString(content, "")

	return zm.atomicWrite(content)
}

// List returns all environment variables stored in ~/.zshenv
func (zm *ZshenvManager) List() ([]EnvVar, error) {
	content, err := zm.readFile()
	if err != nil {
		if os.IsNotExist(err) {
			return []EnvVar{}, nil
		}
		return nil, err
	}

	var vars []EnvVar
	pattern := regexp.MustCompile(`^export ([A-Za-z_][A-Za-z0-9_]*)="(.*)"$`)

	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if matches := pattern.FindStringSubmatch(line); matches != nil {
			vars = append(vars, EnvVar{
				Key:   matches[1],
				Value: unescapeValue(matches[2]),
			})
		}
	}

	return vars, scanner.Err()
}

// EnsurePermissions sets the file permissions to 600 (owner read/write only)
func (zm *ZshenvManager) EnsurePermissions() error {
	if _, err := os.Stat(zm.Path); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	return os.Chmod(zm.Path, 0600)
}

// readFile reads the content of ~/.zshenv
func (zm *ZshenvManager) readFile() (string, error) {
	content, err := os.ReadFile(zm.Path)
	if err != nil {
		if os.IsNotExist(err) {
			return "", nil
		}
		return "", err
	}
	return string(content), nil
}

// atomicWrite writes content to a temp file then renames it for atomic operation
func (zm *ZshenvManager) atomicWrite(content string) error {
	dir := filepath.Dir(zm.Path)

	// Create temp file in the same directory
	tempFile, err := os.CreateTemp(dir, ".zshenv.tmp.*")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	tempPath := tempFile.Name()

	// Ensure cleanup on error
	cleanup := func() {
		_ = os.Remove(tempPath)
	}

	// Write content
	if _, err := tempFile.WriteString(content); err != nil {
		cleanup()
		return fmt.Errorf("failed to write temp file: %w", err)
	}

	if err := tempFile.Close(); err != nil {
		cleanup()
		return fmt.Errorf("failed to close temp file: %w", err)
	}

	// Set permissions before renaming
	if err := os.Chmod(tempPath, 0600); err != nil {
		cleanup()
		return fmt.Errorf("failed to set permissions: %w", err)
	}

	// Atomic rename
	if err := os.Rename(tempPath, zm.Path); err != nil {
		cleanup()
		return fmt.Errorf("failed to rename temp file: %w", err)
	}

	return nil
}

// escapeValue escapes special characters in the value for shell compatibility
func escapeValue(value string) string {
	value = strings.ReplaceAll(value, `\`, `\\`)
	value = strings.ReplaceAll(value, `"`, `\"`)
	value = strings.ReplaceAll(value, `$`, `\$`)
	value = strings.ReplaceAll(value, "`", "\x60") // backtick
	return value
}

// unescapeValue reverses escapeValue
func unescapeValue(value string) string {
	value = strings.ReplaceAll(value, "\x60", "`") // backtick
	value = strings.ReplaceAll(value, `\$`, `$`)
	value = strings.ReplaceAll(value, `\"`, `"`)
	value = strings.ReplaceAll(value, `\\`, `\`)
	return value
}

// IsSensitive checks if a key contains sensitive keywords
func IsSensitive(key string) bool {
	sensitiveKeywords := []string{"TOKEN", "KEY", "SECRET", "PASSWORD", "PASS", "AUTH", "PWD"}
	upperKey := strings.ToUpper(key)
	for _, keyword := range sensitiveKeywords {
		if strings.Contains(upperKey, keyword) {
			return true
		}
	}
	return false
}
