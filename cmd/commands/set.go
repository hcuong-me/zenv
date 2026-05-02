package commands

import (
	"fmt"

	"github.com/hcuong-me/zenv/internal/shell"
	"github.com/hcuong-me/zenv/internal/storage"
	"github.com/hcuong-me/zenv/internal/tui"
	"github.com/spf13/cobra"
)

// setCmd represents the set command
var setCmd = &cobra.Command{
	Use:   "set",
	Short: "Add or update an environment variable",
	Long: `Opens an interactive TUI form to securely set an environment variable.

The key will be automatically converted to uppercase.
The value will be masked with asterisks (*) for security.

This command ensures the secret never appears in shell history.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Check if running in zsh
		if !shell.CheckZsh() {
			fmt.Println("Warning: zenv is designed for Zsh. Some features may not work correctly.")
		}

		// Show TUI form
		key, value, err := tui.ShowSetForm()
		if err != nil {
			// User cancelled or error
			return nil // Silent exit on cancel (behavior #25)
		}

		// Validate value is not empty (behavior #26)
		if value == "" {
			fmt.Println("Error: value cannot be empty")
			return fmt.Errorf("empty value")
		}

		zm := storage.NewZshenvManager()

		// Check if key exists before setting
		vars, _ := zm.List()
		wasUpdate := false
		for _, v := range vars {
			if v.Key == key {
				wasUpdate = true
				break
			}
		}

		// Save to ~/.zshenv
		if err := zm.Set(key, value); err != nil {
			return fmt.Errorf("failed to save variable: %w", err)
		}

		// Note: Cannot load env var into parent shell from child process
		// User needs to source ~/.zshenv or open new terminal

		if wasUpdate {
			fmt.Printf("✓ Updated %s\n", key)
		} else {
			fmt.Printf("✓ Added %s\n", key)
		}
		fmt.Println("\n⚠ Run 'source ~/.zshenv' or restart your terminal to use this variable.")

		return nil
	},
}

func init() {
	rootCmd.AddCommand(setCmd)
}
