package commands

import (
	"fmt"
	"os"

	"charm.land/lipgloss/v2"
	"charm.land/lipgloss/v2/table"
	"github.com/hcuong-me/zenv/internal/shell"
	"github.com/hcuong-me/zenv/internal/storage"
	"github.com/hcuong-me/zenv/internal/tui"
	"github.com/spf13/cobra"
)

// migrateCmd represents the migrate command
var migrateCmd = &cobra.Command{
	Use:   "migrate",
	Short: "Migrate environment variables from ~/.zshrc to ~/.zshenv",
	Long: `Scans ~/.zshrc for export statements and migrates them to ~/.zshenv.

This helps transition from managing env vars in .zshrc to using zenv.
Variables already in ~/.zshenv will be skipped.
A backup of ~/.zshrc is created before modification.`,
	RunE: runMigrate,
}

func runMigrate(cmd *cobra.Command, args []string) error {
	// Check if ~/.zshrc exists (behavior #13)
	zshrcPath := shell.NewZshrcManager().Path
	if _, err := os.Stat(zshrcPath); err != nil {
		if os.IsNotExist(err) {
			fmt.Println("❌ Error: ~/.zshrc not found.")
			return fmt.Errorf("~/.zshrc not found")
		}
		fmt.Printf("❌ Error: cannot access ~/.zshrc: %v\n", err)
		return err
	}

	// Parse exports from ~/.zshrc (behavior #1-2)
	vars, err := shell.ParseExportsFromZshrc(zshrcPath)
	if err != nil {
		fmt.Printf("❌ Error parsing ~/.zshrc: %v\n", err)
		return err
	}

	// Check if any vars found (behavior #3)
	if len(vars) == 0 {
		fmt.Println("No environment variables found in ~/.zshrc.")
		return nil
	}

	// Extract keys for selection
	keys := make([]string, len(vars))
	for i, v := range vars {
		keys[i] = v.Key
	}

	// Multi-select keys to migrate (behavior #5-7)
	selectedKeys, err := tui.SelectKeysDialog(keys)
	if err != nil {
		// User cancelled (behavior #19)
		return nil
	}

	// Check if any keys selected (behavior #10)
	if len(selectedKeys) == 0 {
		fmt.Println("No variables selected. Migration cancelled.")
		return nil
	}

	// Filter vars to only selected keys
	selectedVars := []storage.EnvVar{}
	for _, v := range vars {
		for _, key := range selectedKeys {
			if v.Key == key {
				selectedVars = append(selectedVars, v)
				break
			}
		}
	}

	// Display preview table (behavior #11) - only selected keys, max 20
	fmt.Printf("\nSelected %d variable(s) to migrate:\n\n", len(selectedVars))

	rows := [][]string{}
	displayCount := len(selectedVars)
	showMore := false
	if displayCount > 20 {
		displayCount = 20
		showMore = true
	}

	for i := 0; i < displayCount; i++ {
		rows = append(rows, []string{selectedVars[i].Key, "********"})
	}
	if showMore {
		rows = append(rows, []string{"...", fmt.Sprintf("... and %d more", len(selectedVars)-20)})
	}

	// lipgloss v2 API
	headerStyle := lipgloss.NewStyle().Padding(0, 1).Bold(true)
	rowStyle := lipgloss.NewStyle().Padding(0, 1)
	borderStyle := lipgloss.NewStyle()

	t := table.New().
		Border(lipgloss.NormalBorder()).
		BorderStyle(borderStyle).
		Headers("KEY", "VALUE").
		Rows(rows...).
		StyleFunc(func(row, col int) lipgloss.Style {
			if row == table.HeaderRow {
				return headerStyle
			}
			return rowStyle
		})

	fmt.Println(t)
	fmt.Println()

	// Confirm migration (behavior #12-14)
	confirmed, err := tui.ConfirmDialog(
		"Migrate these variables?",
		fmt.Sprintf("This will move %d variable(s) from ~/.zshrc to ~/.zshenv.", len(selectedVars)),
	)
	if err != nil {
		// User cancelled (behavior #22)
		return nil
	}

	if !confirmed {
		fmt.Println("Migration cancelled.")
		return nil
	}

	// Perform migration
	result, err := performMigration(selectedVars)
	if err != nil {
		fmt.Printf("❌ Migration failed: %v\n", err)
		return err
	}

	// Create backup and remove from ~/.zshrc (behavior #17-18)
	if len(result.Migrated) > 0 {
		backupPath := shell.GetBackupPathWithTimestamp(zshrcPath)
		if err := shell.RemoveExportsFromZshrc(zshrcPath, result.Migrated, backupPath); err != nil {
			fmt.Printf("⚠ Warning: migrated to ~/.zshenv but failed to clean up ~/.zshrc: %v\n", err)
			fmt.Printf("   Backup location: %s\n", backupPath)
		}
		result.BackupPath = backupPath
	}

	// Display results (behavior #19)
	fmt.Println()
	fmt.Println("✓ Migration complete!")
	fmt.Printf("  - Migrated: %d variable(s)\n", len(result.Migrated))
	if len(result.Skipped) > 0 {
		fmt.Printf("  - Skipped (already exists): %d variable(s)\n", len(result.Skipped))
		for _, key := range result.Skipped {
			fmt.Printf("    • %s\n", key)
		}
	}
	if len(result.Migrated) > 0 {
		fmt.Printf("  - Backup: %s\n", result.BackupPath)
	}
	fmt.Println()
	fmt.Println("⚠ Run 'source ~/.zshenv' to load the migrated variables.")

	return nil
}

// MigrationResult tracks the outcome of migration
type MigrationResult struct {
	Migrated   []string
	Skipped    []string
	Failed     []string
	BackupPath string
}

// performMigration migrates vars to ~/.zshenv (behavior #15-16)
func performMigration(vars []storage.EnvVar) (*MigrationResult, error) {
	zm := storage.NewZshenvManager()

	// Get existing keys in ~/.zshenv
	existing, err := zm.List()
	if err != nil {
		return nil, err
	}
	existingKeys := make(map[string]bool)
	for _, v := range existing {
		existingKeys[v.Key] = true
	}

	result := &MigrationResult{}

	for _, v := range vars {
		// Check if already exists (behavior #15)
		if existingKeys[v.Key] {
			result.Skipped = append(result.Skipped, v.Key)
			continue
		}

		// Add to ~/.zshenv
		if err := zm.Set(v.Key, v.Value); err != nil {
			result.Failed = append(result.Failed, v.Key)
			continue
		}

		result.Migrated = append(result.Migrated, v.Key)
	}

	// Ensure permissions (behavior #16)
	if err := zm.EnsurePermissions(); err != nil {
		return result, err
	}

	return result, nil
}

func init() {
	rootCmd.AddCommand(migrateCmd)
}
