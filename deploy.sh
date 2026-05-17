#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$ROOT_DIR/packages/contract/script/deploy_common.sh"
load_project_env "$ROOT_DIR"
run_deploy_cli "$@"
