// =============================================================================
// ESLINT FLAT CONFIG TEMPLATE
// =============================================================================
//
// Modern ESLint configuration using the flat config format (ESLint v9+).
// Copy this file to your project root and customize as needed.
//
// Prerequisites (install in your project):
//   npm install --save-dev eslint @eslint/js
//
// For TypeScript projects, also install:
//   npm install --save-dev typescript-eslint
//
// For Prettier compatibility, also install:
//   npm install --save-dev eslint-config-prettier
//
// See: https://eslint.org/docs/latest/use/configure/configuration-files
//

import eslint from "@eslint/js";
import prettier from "eslint-config-prettier";
import tseslint from "typescript-eslint";

export default tseslint.config(
	// =============================================================================
	// GLOBAL IGNORES
	// =============================================================================
	// Files/directories to ignore globally. These are never linted.
	{
		ignores: [
			// Build outputs
			"dist/**",
			"build/**",
			".next/**",
			"out/**",

			// Dependencies
			"node_modules/**",

			// Generated files
			"*.generated.*",
			"*.min.js",
			"coverage/**",

			// Package manager files
			"pnpm-lock.yaml",
			"package-lock.json",
			"yarn.lock",
		],
	},

	// =============================================================================
	// BASE CONFIGURATION
	// =============================================================================
	// ESLint recommended rules for all JavaScript/TypeScript files.
	eslint.configs.recommended,

	// =============================================================================
	// TYPESCRIPT CONFIGURATION
	// =============================================================================
	// typescript-eslint recommended rules. Includes type-aware rules.
	// If you don't use TypeScript, remove this section and the tseslint import.
	...tseslint.configs.recommended,

	// =============================================================================
	// PRETTIER COMPATIBILITY
	// =============================================================================
	// Disables ESLint rules that conflict with Prettier formatting.
	// Must come last to override other configs.
	// If you don't use Prettier, remove this section and the prettier import.
	prettier,

	// =============================================================================
	// CUSTOM RULES
	// =============================================================================
	// Project-specific rule overrides and customizations.
	{
		rules: {
			// Example: Allow unused variables prefixed with underscore
			// '@typescript-eslint/no-unused-vars': [
			//   'error',
			//   { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
			// ],
			// Example: Enforce consistent type imports
			// '@typescript-eslint/consistent-type-imports': 'error',
		},
	},
);
