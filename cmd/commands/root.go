package commands

import (
	"os"

	"github.com/spf13/cobra"
)

// Version is the current version of zenv
const Version = "1.0.0"

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "zenv",
	Short: "Secure Shell Environment Manager",
	Long: `zenv helps you manage sensitive environment variables securely.

It prevents secrets from appearing in shell history and masks sensitive
values when displaying environment variables with 'env'.

Quick Start:
  zenv doctor    Check and configure shell environment
  zenv set       Add or update an environment variable
  zenv ls        List managed environment variables
  zenv rm        Remove an environment variable

Examples:
  zenv set                    # Interactive TUI to add/update a variable
  zenv rm API_KEY             # Remove a variable
  zenv version                # Show version`,
	Run: func(cmd *cobra.Command, args []string) {
		// Show help when called without subcommands
		_ = cmd.Help()
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	// Add --version flag
	rootCmd.Version = Version
	rootCmd.SetVersionTemplate(`zenv version {{.Version}}
`)
}

// GetRootCmd returns the root command for testing purposes
func GetRootCmd() *cobra.Command {
	return rootCmd
}
