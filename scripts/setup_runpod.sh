#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
COMFY_DIR="${COMFY_DIR:-${WORKSPACE_DIR}/ComfyUI}"
MODELS_DIR="${MODELS_DIR:-${COMFY_DIR}/models}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKFLOW_FILE="${WORKFLOW_FILE:-${REPO_DIR}/workflows/Sulphur 2 (GGUF).json}"
DOWNLOAD_GGUF_MODELS="${DOWNLOAD_GGUF_MODELS:-1}"
DOWNLOAD_WORKFLOWS="${DOWNLOAD_WORKFLOWS:-1}"
DOWNLOAD_RANK_LORA="${DOWNLOAD_RANK_LORA:-1}"
DOWNLOAD_FRAME_INTERPOLATION="${DOWNLOAD_FRAME_INTERPOLATION:-1}"
DOWNLOAD_PROMPT_ENHANCER="${DOWNLOAD_PROMPT_ENHANCER:-0}"
INSTALL_LTXVIDEO_NODES="${INSTALL_LTXVIDEO_NODES:-0}"
INSTALL_TORCH="${INSTALL_TORCH:-auto}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"
COMFYUI_REPO="${COMFYUI_REPO:-https://github.com/comfyanonymous/ComfyUI.git}"
COMFYUI_MANAGER_REPO="${COMFYUI_MANAGER_REPO:-https://github.com/ltdrdata/ComfyUI-Manager.git}"
LTXVIDEO_REPO="${LTXVIDEO_REPO:-https://github.com/Lightricks/ComfyUI-LTXVideo.git}"
LTX2_SM_REPO="${LTX2_SM_REPO:-https://github.com/smthemex/ComfyUI_LTX2_SM.git}"
GGUF_REPO="${GGUF_REPO:-smthem/LTX-2.3-test-gguf}"
VAE_REPO="${VAE_REPO:-Kijai/LTX2.3_comfy}"
UPSCALE_REPO="${UPSCALE_REPO:-Lightricks/LTX-2.3}"
FRAME_INTERPOLATION_REPO="${FRAME_INTERPOLATION_REPO:-Comfy-Org/frame_interpolation}"
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
  "$(venv_pip)" install --upgrade huggingface_hub hf_transfer hf_xet
}

install_custom_nodes() {
  mkdir -p "${COMFY_DIR}/custom_nodes"
  clone_or_update "${COMFYUI_MANAGER_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-Manager" "ComfyUI-Manager"
  clone_or_update "${LTX2_SM_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI_LTX2_SM" "ComfyUI_LTX2_SM"

  if [[ "${INSTALL_LTXVIDEO_NODES}" == "1" ]]; then
    clone_or_update "${LTXVIDEO_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-LTXVideo" "ComfyUI-LTXVideo"
  fi

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

install_workflow_file() {
  if [[ "${DOWNLOAD_WORKFLOWS}" != "1" ]]; then
    log "Skipping workflow install"
    return
  fi

  if [[ ! -f "${WORKFLOW_FILE}" ]]; then
    echo "Workflow file not found: ${WORKFLOW_FILE}" >&2
    exit 1
  fi

  mkdir -p "${COMFY_DIR}/user/default/workflows"
  log "Installing workflow: ${WORKFLOW_FILE}"
  cp "${WORKFLOW_FILE}" "${COMFY_DIR}/user/default/workflows/"
}

write_example_input() {
  mkdir -p "${COMFY_DIR}/input"
  if [[ -f "${COMFY_DIR}/input/example.png" ]]; then
    log "Keeping existing ${COMFY_DIR}/input/example.png"
    return
  fi

  log "Writing neutral example input image"
  "$(venv_python)" - "${COMFY_DIR}/input/example.png" <<'PY'
import sys
from pathlib import Path

from PIL import Image, ImageDraw

target = Path(sys.argv[1])
image = Image.new("RGB", (512, 512), "#1b1f2a")
draw = ImageDraw.Draw(image)
for y in range(512):
    shade = int(28 + y * 0.18)
    draw.line([(0, y), (512, y)], fill=(shade, 36, 52))
draw.ellipse((156, 72, 356, 272), fill=(188, 170, 150))
draw.rectangle((184, 270, 328, 438), fill=(54, 72, 96))
draw.rectangle((0, 438, 512, 512), fill=(20, 24, 32))
image.save(target)
PY
}

download_gguf_workflow_models() {
  mkdir -p \
    "${MODELS_DIR}/checkpoints" \
    "${MODELS_DIR}/frame_interpolation" \
    "${MODELS_DIR}/gguf" \
    "${MODELS_DIR}/latent_upscale_models" \
    "${MODELS_DIR}/loras" \
    "${MODELS_DIR}/vae" \
    "${WORKSPACE_DIR}/sulphur_prompt_enhancer"

  if [[ "${DOWNLOAD_GGUF_MODELS}" == "1" ]]; then
    download_hf_file "${GGUF_REPO}" "sulphur_distil-Q6_K.gguf" "${MODELS_DIR}/gguf"
    download_hf_file "${GGUF_REPO}" "gemma-3-12b-it-qat-Q4_0.gguf" "${MODELS_DIR}/gguf"
    download_hf_file "${GGUF_REPO}" "connector-11.safetensors" "${MODELS_DIR}/checkpoints"
    download_hf_file "${VAE_REPO}" "vae/LTX23_video_vae_bf16.safetensors" "${MODELS_DIR}/vae"
    download_hf_file "${VAE_REPO}" "vae/LTX23_audio_vae_bf16.safetensors" "${MODELS_DIR}/vae"
    download_hf_file "${UPSCALE_REPO}" "ltx-2.3-spatial-upscaler-x2-1.1.safetensors" "${MODELS_DIR}/latent_upscale_models"
  else
    log "Skipping GGUF workflow model downloads"
  fi

  if [[ "${DOWNLOAD_RANK_LORA}" == "1" ]]; then
    download_hf_file "${SULPHUR_REPO}" "sulphur_lora_rank_768.safetensors" "${MODELS_DIR}/loras"
  fi

  if [[ "${DOWNLOAD_FRAME_INTERPOLATION}" == "1" ]]; then
    download_hf_file "${FRAME_INTERPOLATION_REPO}" "frame_interpolation/film_net_fp16.safetensors" "${MODELS_DIR}/frame_interpolation"
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
  download_gguf_workflow_models
  install_workflow_file
  write_example_input
  write_start_script

  log "Done"
  cat <<EOF

Start ComfyUI:
  ${WORKSPACE_DIR}/start_comfyui.sh

RunPod port:
  expose/open HTTP port 8188

Important:
  The Sulphur 2 GGUF workflow is copied to:
  ${COMFY_DIR}/user/default/workflows
EOF
}

main "$@"
