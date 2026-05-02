package commands

import (
	"fmt"

	"charm.land/lipgloss/v2"
	"charm.land/lipgloss/v2/table"
	"github.com/hcuong-me/zenv/internal/storage"
	"github.com/spf13/cobra"
)

// listCmd represents the ls command
var listCmd = &cobra.Command{
	Use:     "ls",
	Aliases: []string{"list"},
	Short:   "List managed environment variables",
	Long: `Lists all environment variables stored in ~/.zshenv.

Sensitive values are masked with asterisks for security.
This is an internal command for quick verification.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		zm := storage.NewZshenvManager()
		vars, err := zm.List()
		if err != nil {
			return fmt.Errorf("failed to list variables: %w", err)
		}

		// Check if empty (behavior #17)
		if len(vars) == 0 {
			fmt.Println("No environment variables set.")
			return nil
		}

		// Prepare table data - mask ALL values from ~/.zshenv
		rows := [][]string{}
		for _, v := range vars {
			displayValue := "********"
			rows = append(rows, []string{v.Key, displayValue})
		}

		// Create styled table (behavior #16) - lipgloss v2 API
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

		// Also show count
		fmt.Printf("\n%d variable(s) stored in ~/.zshenv\n", len(vars))

		return nil
	},
}

func init() {
	rootCmd.AddCommand(listCmd)
}
