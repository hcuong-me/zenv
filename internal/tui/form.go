// Package tui provides terminal user interface components using huh
package tui

import (
	"errors"
	"fmt"
	"strings"

	"charm.land/huh/v2"
	"charm.land/lipgloss/v2"
)

// ShowSetForm displays the TUI form for setting an environment variable
// Shows Key and Value prompts sequentially (one at a time)
// Returns the key and value entered by the user, or an error if cancelled
func ShowSetForm() (key, value string, err error) {
	var formKey, formValue string

	// First prompt: Key
	keyForm := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Environment Variable Key").
				Placeholder("e.g., STRIPE_KEY").
				Value(&formKey).
				Validate(func(s string) error {
					if strings.TrimSpace(s) == "" {
						return errors.New("key cannot be empty")
					}
					// Convert to uppercase
					formKey = strings.ToUpper(strings.TrimSpace(formKey))
					return nil
				}),
		),
	)

	if err := keyForm.WithTheme(huh.ThemeFunc(huh.ThemeCharm)).Run(); err != nil {
		if errors.Is(err, huh.ErrUserAborted) {
			return "", "", errors.New("cancelled by user")
		}
		return "", "", err
	}

	// Second prompt: Value (after Key is entered)
	valueForm := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title(fmt.Sprintf("Value for %s", formKey)).
				Placeholder("Enter the secret value").
				EchoMode(huh.EchoModePassword).
				Value(&formValue).
				Validate(func(s string) error {
					// Value can be empty
					return nil
				}),
		),
	)

	if err := valueForm.WithTheme(huh.ThemeFunc(huh.ThemeCharm)).Run(); err != nil {
		if errors.Is(err, huh.ErrUserAborted) {
			return "", "", errors.New("cancelled by user")
		}
		return "", "", err
	}

	return formKey, formValue, nil
}

// ConfirmDialog shows a yes/no confirmation dialog
func ConfirmDialog(title, description string) (bool, error) {
	var confirmed bool

	confirm := huh.NewConfirm().
		Title(title).
		Description(description).
		Affirmative("Yes").
		Negative("No").
		WithButtonAlignment(lipgloss.Left).
		Value(&confirmed)

	if err := confirm.WithTheme(huh.ThemeFunc(huh.ThemeCharm)).Run(); err != nil {
		if errors.Is(err, huh.ErrUserAborted) {
			return false, errors.New("cancelled by user")
		}
		return false, err
	}

	return confirmed, nil
}

// ShowMessage displays a simple message (success or info)
func ShowMessage(title, message string) error {
	note := huh.NewNote().
		Title(title).
		Description(message)

	return note.WithTheme(huh.ThemeFunc(huh.ThemeCharm)).Run()
}

// SelectKeysDialog shows a filterable multi-select dialog for choosing keys to migrate
// Supports ESC to exit, Space to select/unselect, and / to start filtering
// Returns the selected keys, or an error if cancelled
func SelectKeysDialog(allKeys []string) ([]string, error) {
	if len(allKeys) == 0 {
		return []string{}, nil
	}

	// Build options - all keys are options
	options := make([]huh.Option[string], len(allKeys))
	for i, key := range allKeys {
		options[i] = huh.NewOption(key, key)
	}

	// Use filterable multi-select wrapped in Form for help display
	var selected []string
	multiSelect := huh.NewMultiSelect[string]().
		Title(fmt.Sprintf("Select variables to migrate (%d found)", len(allKeys))).
		Options(options...).
		Value(&selected).
		Limit(10).
		Filterable(true). // Enable built-in filtering
		Height(15)        // Limit height for better UX

	form := huh.NewForm(
		huh.NewGroup(multiSelect),
	).WithTheme(huh.ThemeFunc(huh.ThemeCharm)).
		WithShowHelp(true)

	if err := form.Run(); err != nil {
		if errors.Is(err, huh.ErrUserAborted) {
			return nil, errors.New("cancelled by user")
		}
		return nil, err
	}

	return selected, nil
}
