package commands

import (
	"fmt"
	"os"

	"github.com/hcuong-me/zenv/internal/shell"
	"github.com/hcuong-me/zenv/internal/storage"
	"github.com/hcuong-me/zenv/internal/tui"
	"github.com/spf13/cobra"
)

// doctorCmd represents the doctor command
var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Check and configure shell environment",
	Long: `Checks the shell configuration and installs necessary hooks.

This command will:
1. Check if you're using Zsh
2. Verify the shell hook is installed in ~/.zshrc
3. Check file permissions on ~/.zshenv
4. Install the hook if missing (with confirmation)`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Check shell (behavior #27-28)
		if !shell.CheckZsh() {
			fmt.Println("❌ Error: Only Zsh is supported.")
			fmt.Printf("   Current shell: %s\n", os.Getenv("SHELL"))
			return fmt.Errorf("unsupported shell")
		}
		fmt.Println("✓ Using Zsh shell")

		// Check ~/.zshrc exists (behavior #23)
		zshrc := shell.NewZshrcManager()
		if _, err := os.Stat(zshrc.Path); err != nil {
			if os.IsNotExist(err) {
				fmt.Println("❌ Error: ~/.zshrc not found")
				fmt.Println("   Please create it first: touch ~/.zshrc")
				return fmt.Errorf("~/.zshrc not found")
			}
		}
		fmt.Println("✓ ~/.zshrc exists")

		// Check if hook is installed (behavior #1-2)
		if zshrc.IsHookInstalled() {
			fmt.Println("✓ zenv shell hook is installed")
		} else {
			fmt.Println("⚠ zenv shell hook is not installed")

			// Ask for confirmation (behavior #2)
			confirmed, err := tui.ConfirmDialog(
				"Install Shell Hook?",
				"This will add a script to ~/.zshrc that masks sensitive environment variables when running 'env'.",
			)
			if err != nil {
				return nil // User cancelled
			}

			if confirmed {
				if err := zshrc.InstallHook(); err != nil {
					fmt.Printf("❌ Failed to install hook: %v\n", err)
					return err
				}
				fmt.Println("✓ Shell hook installed successfully")
				fmt.Println("\n⚠ Please restart your terminal or run: source ~/.zshrc")
			} else {
				fmt.Println("Installation cancelled.")
			}
		}

		// Check ~/.zshenv permissions (behavior #21-22)
		zm := storage.NewZshenvManager()
		if info, err := os.Stat(zm.Path); err == nil {
			mode := info.Mode().Perm()
			if mode == 0600 {
				fmt.Println("✓ ~/.zshenv has correct permissions (600)")
			} else {
				fmt.Printf("⚠ ~/.zshenv permissions are %04o (should be 600)\n", mode)
				confirmed, err := tui.ConfirmDialog(
					"Fix Permissions?",
					"This will set ~/.zshenv permissions to 600 (owner read/write only).",
				)
				if err != nil {
					return nil // User cancelled
				}
				if confirmed {
					if err := zm.EnsurePermissions(); err != nil {
						fmt.Printf("❌ Failed to fix permissions: %v\n", err)
					} else {
						fmt.Println("✓ Permissions fixed")
					}
				}
			}
		} else if os.IsNotExist(err) {
			fmt.Println("⚠ ~/.zshenv does not exist yet (will be created on first 'zenv set')")
		}

		fmt.Println("\n✓ Doctor check complete!")
		return nil
	},
}

func init() {
	rootCmd.AddCommand(doctorCmd)
}
