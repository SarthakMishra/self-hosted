#!/bin/bash
# Validates .env.example files use consistent placeholder conventions
# Used as a pre-commit hook

set -e

ERRORS=0

# Patterns that should NOT appear (old inconsistent placeholders)
INVALID_PATTERNS=(
    "yourdomain\.com"
    "your_secure"
    "your-secure"
    "your_very"
    "your-very"
    "change-this"
    "change_this"
    "_here$"
    "your_.*_password"
    "your-.*-password"
)

# Find all env.example files
FILES=$(find . -type f \( -name "*.example" -o -name ".env.example" \) ! -path "./.git/*" 2>/dev/null)

for file in $FILES; do
    for pattern in "${INVALID_PATTERNS[@]}"; do
        if grep -qiE "$pattern" "$file" 2>/dev/null; then
            echo "ERROR: $file contains non-standard placeholder matching: $pattern"
            grep -inE "$pattern" "$file" | head -3
            ERRORS=$((ERRORS + 1))
        fi
    done
done

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "Found $ERRORS placeholder convention violations."
    echo "Use 'changeme' for secrets/passwords and 'example.com' for domains."
    exit 1
fi

echo "All env.example files use consistent placeholders."
exit 0
