#!/usr/bin/env bash
set -Eeuo pipefail

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
COMFY_HOST="${COMFY_HOST:-0.0.0.0}"
COMFY_PORT="${COMFY_PORT:-8188}"

cd "${COMFY_DIR}"
source "${COMFY_DIR}/venv/bin/activate"
python main.py --listen "${COMFY_HOST}" --port "${COMFY_PORT}" "$@"
