package commands

import (
	"fmt"

	"github.com/spf13/cobra"
)

// versionCmd represents the version command
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show version information",
	Long:  `Displays the current version of zenv.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("zenv version %s\n", Version)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
