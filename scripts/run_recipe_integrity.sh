#!/usr/bin/env bash
set -euo pipefail
source venv/bin/activate
python src/recipe_integrity_check.py
