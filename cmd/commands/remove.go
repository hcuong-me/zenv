package commands

import (
	"fmt"

	"github.com/hcuong-me/zenv/internal/shell"
	"github.com/hcuong-me/zenv/internal/storage"
	"github.com/spf13/cobra"
)

// removeCmd represents the rm command
var removeCmd = &cobra.Command{
	Use:     "rm [KEY]",
	Aliases: []string{"remove", "delete"},
	Short:   "Remove an environment variable",
	Long: `Removes an environment variable from ~/.zshenv.

The variable will be deleted from storage and unset from the current session.`,
	Args: cobra.ExactArgs(1), // Require exactly one argument (behavior #18)
	RunE: func(cmd *cobra.Command, args []string) error {
		key := args[0]

		zm := storage.NewZshenvManager()

		// Remove from ~/.zshenv (behavior #19)
		if err := zm.Remove(key); err != nil {
			fmt.Printf("❌ Error: %v\n", err)
			return fmt.Errorf("remove failed: %w", err)
		}

		// Unset from current session (behavior #20)
		if err := shell.UnsetEnv(key); err != nil {
			fmt.Printf("⚠ Warning: removed from ~/.zshenv but couldn't unset from current session: %v\n", err)
		}

		fmt.Printf("✓ Removed %s\n", key)
		return nil
	},
}

func init() {
	rootCmd.AddCommand(removeCmd)
}
