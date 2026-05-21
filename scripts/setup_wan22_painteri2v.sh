#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
COMFY_DIR="${COMFY_DIR:-${WORKSPACE_DIR}/ComfyUI}"
MODELS_DIR="${MODELS_DIR:-${COMFY_DIR}/models}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKFLOW_FILE="${WORKFLOW_FILE:-${REPO_DIR}/workflows/Wan2.2_I2V_PainterI2V_Workflow_Kenpechi_v2.4.json}"

DOWNLOAD_GGUF_MODELS="${DOWNLOAD_GGUF_MODELS:-1}"
DOWNLOAD_SAFETENSORS_MODELS="${DOWNLOAD_SAFETENSORS_MODELS:-0}"
DOWNLOAD_LIGHTX2V_LORAS="${DOWNLOAD_LIGHTX2V_LORAS:-1}"
DOWNLOAD_FFGO_LORAS="${DOWNLOAD_FFGO_LORAS:-1}"
DOWNLOAD_UPSCALE_MODEL="${DOWNLOAD_UPSCALE_MODEL:-1}"
DOWNLOAD_RIFE_MODEL="${DOWNLOAD_RIFE_MODEL:-1}"
DOWNLOAD_WORKFLOW="${DOWNLOAD_WORKFLOW:-1}"
INSTALL_TORCH="${INSTALL_TORCH:-auto}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"

COMFYUI_REPO="${COMFYUI_REPO:-https://github.com/comfyanonymous/ComfyUI.git}"
COMFYUI_MANAGER_REPO="${COMFYUI_MANAGER_REPO:-https://github.com/ltdrdata/ComfyUI-Manager.git}"
RGTHREE_REPO="${RGTHREE_REPO:-https://github.com/rgthree/rgthree-comfy.git}"
KJNODES_REPO="${KJNODES_REPO:-https://github.com/kijai/ComfyUI-KJNodes.git}"
IMPACT_PACK_REPO="${IMPACT_PACK_REPO:-https://github.com/ltdrdata/ComfyUI-Impact-Pack.git}"
CUSTOM_SCRIPTS_REPO="${CUSTOM_SCRIPTS_REPO:-https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git}"
COMFYUI_GGUF_REPO="${COMFYUI_GGUF_REPO:-https://github.com/city96/ComfyUI-GGUF.git}"
VHS_REPO="${VHS_REPO:-https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git}"
PAINTERI2V_REPO="${PAINTERI2V_REPO:-https://github.com/princepainter/ComfyUI-PainterI2Vadvanced.git}"
FRAME_INTERPOLATION_REPO_GIT="${FRAME_INTERPOLATION_REPO_GIT:-https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git}"

WAN_GGUF_REPO="${WAN_GGUF_REPO:-QuantStack/Wan2.2-I2V-A14B-GGUF}"
WAN_COMFY_REPO="${WAN_COMFY_REPO:-Comfy-Org/Wan_2.2_ComfyUI_Repackaged}"
WAN21_COMFY_REPO="${WAN21_COMFY_REPO:-Comfy-Org/Wan_2.1_ComfyUI_repackaged}"
LIGHTX2V_REPO="${LIGHTX2V_REPO:-lightx2v/Wan2.2-Distill-Loras}"
KIJAI_WANVIDEO_REPO="${KIJAI_WANVIDEO_REPO:-Kijai/WanVideo_comfy}"
REALESRGAN_REPO="${REALESRGAN_REPO:-hoveyc/comfyui-models}"
RIFE_REPO="${RIFE_REPO:-smegmarip/ComfyUI}"

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
  elif [[ -d "${target_dir}" && -f "${target_dir}/main.py" ]]; then
    log "Using existing ${label} at ${target_dir}"
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
  if [[ -x "${COMFY_DIR}/venv/bin/python" ]]; then
    log "Using existing Python virtual environment"
  else
    log "Creating Python virtual environment"
    python3 -m venv "${COMFY_DIR}/venv"
  fi
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
  clone_or_update "${RGTHREE_REPO}" "${COMFY_DIR}/custom_nodes/rgthree-comfy" "rgthree-comfy"
  clone_or_update "${KJNODES_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-KJNodes" "ComfyUI-KJNodes"
  clone_or_update "${IMPACT_PACK_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-Impact-Pack" "ComfyUI-Impact-Pack"
  clone_or_update "${CUSTOM_SCRIPTS_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-Custom-Scripts" "ComfyUI-Custom-Scripts"
  clone_or_update "${COMFYUI_GGUF_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-GGUF" "ComfyUI-GGUF"
  clone_or_update "${VHS_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-VideoHelperSuite" "ComfyUI-VideoHelperSuite"
  clone_or_update "${PAINTERI2V_REPO}" "${COMFY_DIR}/custom_nodes/ComfyUI-PainterI2Vadvanced" "ComfyUI-PainterI2Vadvanced"
  clone_or_update "${FRAME_INTERPOLATION_REPO_GIT}" "${COMFY_DIR}/custom_nodes/ComfyUI-Frame-Interpolation" "ComfyUI-Frame-Interpolation"

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

download_models() {
  mkdir -p \
    "${MODELS_DIR}/clip" \
    "${MODELS_DIR}/diffusion_models" \
    "${MODELS_DIR}/loras/HIGH" \
    "${MODELS_DIR}/loras/LOW" \
    "${MODELS_DIR}/text_encoders" \
    "${MODELS_DIR}/unet" \
    "${MODELS_DIR}/upscale_models" \
    "${MODELS_DIR}/vae" \
    "${COMFY_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife" \
    "${COMFY_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/models/rife"

  download_hf_file "${WAN21_COMFY_REPO}" "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "${MODELS_DIR}/text_encoders"
  cp "${MODELS_DIR}/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "${MODELS_DIR}/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
  download_hf_file "${WAN21_COMFY_REPO}" "split_files/vae/wan_2.1_vae.safetensors" "${MODELS_DIR}/vae"

  if [[ "${DOWNLOAD_GGUF_MODELS}" == "1" ]]; then
    download_hf_file "${WAN_GGUF_REPO}" "HighNoise/Wan2.2-I2V-A14B-HighNoise-Q8_0.gguf" "${MODELS_DIR}/unet"
    download_hf_file "${WAN_GGUF_REPO}" "LowNoise/Wan2.2-I2V-A14B-LowNoise-Q8_0.gguf" "${MODELS_DIR}/unet"
  fi

  if [[ "${DOWNLOAD_SAFETENSORS_MODELS}" == "1" ]]; then
    download_hf_file "${WAN_COMFY_REPO}" "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" "${MODELS_DIR}/diffusion_models"
    download_hf_file "${WAN_COMFY_REPO}" "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" "${MODELS_DIR}/diffusion_models"
  fi

  if [[ "${DOWNLOAD_LIGHTX2V_LORAS}" == "1" ]]; then
    download_hf_file "${KIJAI_WANVIDEO_REPO}" "LoRAs/Wan22_Lightx2v/Wan_2_2_I2V_A14B_HIGH_lightx2v_4step_lora_v1030_rank_64_bf16.safetensors" "${MODELS_DIR}/loras/HIGH"
    download_hf_file "${LIGHTX2V_REPO}" "wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors" "${MODELS_DIR}/loras/LOW"
  fi

  if [[ "${DOWNLOAD_FFGO_LORAS}" == "1" ]]; then
    download_hf_file "${KIJAI_WANVIDEO_REPO}" "LoRAs/Wan22_FFGO/Wan22_FFGO-LoRA-HIGH_bf16.safetensors" "${MODELS_DIR}/loras/HIGH"
    download_hf_file "${KIJAI_WANVIDEO_REPO}" "LoRAs/Wan22_FFGO/Wan22_FFGO-LoRA-LOW_bf16.safetensors" "${MODELS_DIR}/loras/LOW"
  fi

  if [[ "${DOWNLOAD_UPSCALE_MODEL}" == "1" ]]; then
    download_hf_file "${REALESRGAN_REPO}" "upscale_models/RealESRGAN_x2plus.pth" "${MODELS_DIR}/upscale_models"
  fi

  if [[ "${DOWNLOAD_RIFE_MODEL}" == "1" ]]; then
    download_hf_file "${RIFE_REPO}" "rife/rife49.pth" "${COMFY_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife"
    cp "${COMFY_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth" \
      "${COMFY_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/models/rife/rife49.pth"
  fi
}

install_workflow_file() {
  if [[ "${DOWNLOAD_WORKFLOW}" != "1" ]]; then
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
image = Image.new("RGB", (832, 480), "#18202b")
draw = ImageDraw.Draw(image)
for x in range(832):
    shade = int(24 + x * 0.04)
    draw.line([(x, 0), (x, 480)], fill=(shade, 36, 48))
draw.rectangle((0, 350, 832, 480), fill=(24, 30, 36))
draw.ellipse((336, 90, 496, 250), fill=(190, 174, 154))
draw.rectangle((365, 250, 467, 390), fill=(58, 78, 108))
image.save(target)
PY
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
  download_models
  install_workflow_file
  write_example_input
  write_start_script

  log "Done"
  cat <<EOF

Start ComfyUI:
  ${WORKSPACE_DIR}/start_comfyui.sh

RunPod port:
  expose/open HTTP port 8188

Workflow:
  ${COMFY_DIR}/user/default/workflows/$(basename "${WORKFLOW_FILE}")
EOF
}

main "$@"
