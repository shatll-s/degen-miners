#!/bin/bash
set -e

mv screen-kill /usr/bin/screen-kill 2>/dev/null || true

function NeedToInstall() {
  local ver=$(apt-cache policy "$1" | grep Installed | sed 's/Installed://; s/\s*//')
  if [[ $2 ]]; then
    local majorVer=$(echo "$ver" | cut -d- -f1)
    if (( $(echo "$majorVer > $2" | bc -l) )); then
      echo 0
    else
      echo 1
    fi
  else
    [[ $ver && $ver != '(none)' ]] && echo 0 || echo 1
  fi
}

if [[ $(NeedToInstall libc6 "2.32") -eq 1 ]]; then
  echo -e "> Обновление libc6"
  echo "deb http://cz.archive.ubuntu.com/ubuntu jammy main" >> /etc/apt/sources.list
  apt update
  apt install libc6 -yqq --no-install-recommends
else
  echo -e "[✔] libc6 уже установлена"
fi

# Проверка: уже установлено?
if ldconfig -p | grep -q libcublas.so.12; then
  echo "[✔] Уже установлено: libcublas.so.12"
  exit 0
fi

# Определение версии Ubuntu и нужного CUDA-репозитория
UBU_VERSION=$(lsb_release -sr)
case "$UBU_VERSION" in
  "20.04") CUDA_REPO="ubuntu2004" ;;
  "22.04") CUDA_REPO="ubuntu2204" ;;
  "24.04") CUDA_REPO="ubuntu2404" ;;
  *)
    echo "[!] Скрипт поддерживает только Ubuntu 20.04 / 22.04 / 24.04 (а не $UBU_VERSION)"
    exit 1
    ;;
esac

echo "[*] Установка зависимостей"
apt update
apt install -y wget ca-certificates gnupg lsb-release curl

echo "[*] Добавление CUDA репозитория"
PIN_URL="https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO}/x86_64/cuda-${CUDA_REPO}.pin"
wget "$PIN_URL" -O /etc/apt/preferences.d/cuda-repository-pin-600

curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO}/x86_64/3bf863cc.pub \
  | gpg --dearmor | tee /usr/share/keyrings/cuda-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO}/x86_64/ /" \
  > /etc/apt/sources.list.d/cuda.list

echo "[*] Обновление apt"
apt update

echo "[*] Установка библиотек CUDA"
if [[ "$UBU_VERSION" == "24.04" ]]; then
  apt install -y libcublas12 libcudart12
else
  apt install -y cuda-libraries-12-4
fi

echo "[*] Проверка установки libcublas.so.12"
if ldconfig -p | grep -q libcublas.so.12; then
  echo "[✔] Успешно установлено: libcublas.so.12"
else
  echo "[!] Установка libcublas не удалась"
  exit 1
fi
