#!/bin/bash

# Quick wrapper script to update all 3 submodules to latest commits
# Usage: ./update-submodules.sh

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source git utilities
source "$SCRIPT_DIR/scripts/git.sh"

# Run the update
update_all_submodules