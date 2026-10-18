#!/usr/bin/env bash
# Per-repo gate entry point. Declares which toolchains this repo contains and
# delegates; it holds no gate logic of its own.
#   --staged : pre-commit scope (fast) — layer 1 only
#   --full   : pre-push scope — every layer
set -euo pipefail
GOH="${GOH_DIR:-${GOH:-$HOME/Projects/gates_of_heck}}"

# Informational flags never reach the gates below.
case "${1:-}" in
  -h|--help)
    echo "usage: gate.sh [--staged | --full | --doctor [repo] | --help]"
    exit 0 ;;
  --doctor)  exec bash "$GOH/gates/doctor.sh" "${2:-$PWD}" ;;
esac

export GOH_DIR="$GOH"

case "${1:-}" in
  --full)
    # Every layer: the steps .gatesrc declares in GOH_CI_STEPS, structural first.
    # There is no CI behind this tap; this IS the gate a bump must pass.
    exec "$GOH/gates/local_ci.sh" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    ;;
  *)
    exec "$GOH/gates/structural.sh" "$@"
    ;;
esac
