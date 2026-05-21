#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
COMFY_DIR="${COMFY_DIR:-${WORKSPACE_DIR}/ComfyUI}"
MODELS_DIR="${MODELS_DIR:-${COMFY_DIR}/models}"
MODEL_VARIANT="${MODEL_VARIANT:-fp8mixed}"
DOWNLOAD_WORKFLOWS="${DOWNLOAD_WORKFLOWS:-1}"
DOWNLOAD_LORA="${DOWNLOAD_LORA:-1}"
DOWNLOAD_PROMPT_ENHANCER="${DOWNLOAD_PROMPT_ENHANCER:-0}"
INSTALL_TORCH="${INSTALL_TORCH:-auto}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"
COMFYUI_REPO="${COMFYUI_REPO:-https://github.com/comfyanonymous/ComfyUI.git}"
COMFYUI_MANAGER_REPO="${COMFYUI_MANAGER_REPO:-https://github.com/ltdrdata/ComfyUI-Manager.git}"
LTXVIDEO_REPO="${LTXVIDEO_REPO:-https://github.com/Lightricks/ComfyUI-LTXVideo.git}"
SULPHUR_REPO="${SULPHUR_REPO:-SulphurAI/Sulphur-2-base}"

log() {
  printf '\n[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "This script is intended for Linux RunPod containers." >&2
    exit 1
  fi
}

apt_install() {
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing system packages"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      aria2 \
      ca-certificates \
      curl \
      ffmpeg \
      git \
      git-lfs \
      libgl1 \
      libglib2.0-0 \
      python3 \
      python3-pip \
      python3-venv
    git lfs install --skip-repo
  else
    log "apt-get not found; skipping system package install"
  fi
}

clone_or_update() {
  local repo_url="$1"
  local target_dir="$2"
  local label="$3"

  if [[ -d "${target_dir}/.git" ]]; then
    log "Updating ${label}"
    git -C "${target_dir}" pull --ff-only
  else
    log "Cloning ${label}"
    git clone --depth 1 "${repo_url}" "${target_dir}"
  fi
}

venv_python() {
  printf '%s\n' "${COMFY_DIR}/venv/bin/python"
}

venv_pip() {
  printf '%s\n' "${COMFY_DIR}/venv/bin/pip"
}

setup_python() {
  log "Creating Python virtual environment"
  python3 -m venv "${COMFY_DIR}/venv"
  "$(venv_python)" -m pip install --upgrade pip setuptools wheel

  if [[ "${INSTALL_TORCH}" == "1" ]]; then
    log "Installing PyTorch from ${TORCH_INDEX_URL}"
    "$(venv_pip)" install torch torchvision torchaudio --index-url "${TORCH_INDEX_URL}"
  elif [[ "${INSTALL_TORCH}" == "auto" ]]; then
    if ! "$(venv_python)" - <<'PY' >/dev/null 2>&1
import torch
print(torch.__version__)
PY
    then
      log "PyTorch not found in venv; installing from ${TORCH_INDEX_URL}"
      "$(venv_pip)" install torch torchvision torchaudio --index-url "${TORCH_INDEX_URL}"
    else
      log "PyTorch already importable in venv"
    fi
  else
    log "Skipping PyTorch install because INSTALL_TORCH=${INSTALL_TORCH}"
  fi

  log "Installing ComfyUI Python requirements"
  "$(venv_pip)" install -r "${COMFY_DIR}/requirements.txt"
  "$(venv_pip)" install --upgrade huggingface_hub hf_transfer
}

install_custom_nodes() {
  mkdir -p "${COMFY_DIR}/custom_nodes"
  clone_or_update "${COMFYUI_MANAGER_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-Manager" "ComfyUI-Manager"
  clone_or_update "${LTXVIDEO_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-LTXVideo" "ComfyUI-LTXVideo"

  find "${COMFY_DIR}/custom_nodes" -maxdepth 2 -name requirements.txt -print0 |
    while IFS= read -r -d '' req_file; do
      log "Installing custom node requirements: ${req_file}"
      "$(venv_pip)" install -r "${req_file}"
    done
}

download_hf_file() {
  local repo="$1"
  local file="$2"
  local destination="$3"

  mkdir -p "${destination}"
  log "Downloading ${repo}/${file} -> ${destination}"
  HF_HUB_ENABLE_HF_TRANSFER=1 "$(venv_python)" - "${repo}" "${file}" "${destination}" <<'PY'
import shutil
import sys
from pathlib import Path

from huggingface_hub import hf_hub_download

repo_id, filename, destination = sys.argv[1:4]
source = Path(hf_hub_download(repo_id=repo_id, filename=filename))
target = Path(destination) / Path(filename).name
if source.resolve() != target.resolve():
    shutil.copy2(source, target)
print(target)
PY
}

download_sulphur() {
  mkdir -p \
    "${MODELS_DIR}/checkpoints" \
    "${MODELS_DIR}/loras" \
    "${COMFY_DIR}/user/default/workflows" \
    "${WORKSPACE_DIR}/sulphur_prompt_enhancer"

  case "${MODEL_VARIANT}" in
    fp8mixed|fp8)
      download_hf_file "${SULPHUR_REPO}" "sulphur_dev_fp8mixed.safetensors" "${MODELS_DIR}/checkpoints"
      ;;
    bf16|full)
      download_hf_file "${SULPHUR_REPO}" "sulphur_dev_bf16.safetensors" "${MODELS_DIR}/checkpoints"
      ;;
    none|skip)
      log "Skipping base checkpoint download"
      ;;
    *)
      echo "Unsupported MODEL_VARIANT=${MODEL_VARIANT}. Use fp8mixed, bf16, or none." >&2
      exit 1
      ;;
  esac

  if [[ "${DOWNLOAD_LORA}" == "1" ]]; then
    download_hf_file "${SULPHUR_REPO}" "distill_loras/ltx-2.3-22b-distilled-lora-1.1_fro90_ceil72_condsafe.safetensors" "${MODELS_DIR}/loras"
  fi

  if [[ "${DOWNLOAD_WORKFLOWS}" == "1" ]]; then
    download_hf_file "${SULPHUR_REPO}" "workflows/ltx23_t2v base.json" "${COMFY_DIR}/user/default/workflows"
    download_hf_file "${SULPHUR_REPO}" "workflows/ltx23_t2v distilled.json" "${COMFY_DIR}/user/default/workflows"
    download_hf_file "${SULPHUR_REPO}" "workflows/ltx23_i2v base.json" "${COMFY_DIR}/user/default/workflows"
    download_hf_file "${SULPHUR_REPO}" "workflows/ltx23_i2v distilled.json" "${COMFY_DIR}/user/default/workflows"
  fi

  if [[ "${DOWNLOAD_PROMPT_ENHANCER}" == "1" ]]; then
    download_hf_file "${SULPHUR_REPO}" "prompt_enhancer/sulphur_prompt_enhancer_model-q8_0.gguf" "${WORKSPACE_DIR}/sulphur_prompt_enhancer"
    download_hf_file "${SULPHUR_REPO}" "prompt_enhancer/mmproj-BF16.gguf" "${WORKSPACE_DIR}/sulphur_prompt_enhancer"
  fi
}

write_start_script() {
  log "Writing ${WORKSPACE_DIR}/start_comfyui.sh"
  cat > "${WORKSPACE_DIR}/start_comfyui.sh" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "${COMFY_DIR}"
source "${COMFY_DIR}/venv/bin/activate"
python main.py --listen "\${COMFY_HOST:-0.0.0.0}" --port "\${COMFY_PORT:-8188}" "\${@}"
EOF
  chmod +x "${WORKSPACE_DIR}/start_comfyui.sh"
}

main() {
  require_linux
  mkdir -p "${WORKSPACE_DIR}"
  apt_install
  clone_or_update "${COMFYUI_REPO}" "${COMFY_DIR}" "ComfyUI"
  setup_python
  install_custom_nodes
  download_sulphur
  write_start_script

  log "Done"
  cat <<EOF

Start ComfyUI:
  ${WORKSPACE_DIR}/start_comfyui.sh

RunPod port:
  expose/open HTTP port 8188

Important:
  Sulphur 2 workflows are copied to:
  ${COMFY_DIR}/user/default/workflows
EOF
}

main "$@"
