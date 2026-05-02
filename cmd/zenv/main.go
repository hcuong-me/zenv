// zenv - Secure Shell Environment Manager
// Main entry point for the CLI application
package main

import (
	"github.com/hcuong-me/zenv/cmd/commands"
)

func main() {
	commands.Execute()
}
