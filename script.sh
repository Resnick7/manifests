#!/bin/bash
# deploy_static_website.sh

set -euo pipefail

# --- CONFIGURACIÓN DEL ENTORNO ---
PROFILE="${1:-0311at}"
REPO_WEB="https://github.com/Resnick7/static-website.git"
REPO_MANIFESTS="https://github.com/Resnick7/manifests.git"

LOCAL_WEB_DIR="static-website"
LOCAL_MANIFEST_DIR="manifests"
MOUNT_PATH="/static-website"
BASE_DIR="$(pwd)"
AUTO_CONFIRM=false

# Log temporal
LOG_FILE=$(mktemp /tmp/deploy_log.XXXXXX)
echo "Log de instalación: $LOG_FILE"

# --- FUNCIONES AUXILIARES ---

check_tool() {
  if ! command -v "$1" &> /dev/null; then
    echo "❌ $1 no está instalado." | tee -a "$LOG_FILE"
    return 1
  else
    echo "✅ $1 está instalado." | tee -a "$LOG_FILE"
    return 0
  fi
}

install_tool() {
  case "$1" in
    docker)
      echo "Instalando Docker..." | tee -a "$LOG_FILE"
      sudo apt update && sudo apt install -y docker.io
      ;;
    minikube)
      echo "Instalando Minikube..." | tee -a "$LOG_FILE"
      curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
      sudo install minikube-linux-amd64 /usr/local/bin/minikube
      ;;
    kubectl)
      echo "Instalando kubectl..." | tee -a "$LOG_FILE"
      curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      ;;
    git)
      echo "Instalando Git..." | tee -a "$LOG_FILE"
      sudo apt update && sudo apt install -y git
      ;;
    *)
      echo "⚠️ No se pudo instalar $1 automáticamente. Intente instalar manualmente." | tee -a "$LOG_FILE"
      ;;
  esac
}

# --- PARÁMETROS Y OPCIONES ---
for arg in "$@"; do
  if [[ "$arg" == "-y" || "$arg" == "--yes" ]]; then
    AUTO_CONFIRM=true
  fi
done

# --- VERIFICACIÓN DE DEPENDENCIAS ---
REQUIRED_TOOLS=("docker" "minikube" "kubectl" "git")

echo "Verificando herramientas necesarias..." | tee -a "$LOG_FILE"
for tool in "${REQUIRED_TOOLS[@]}"; do
  check_tool "$tool" || install_tool "$tool"
done

# --- VERIFICACIÓN DE CONFLICTOS CON EL PERFIL ---
if minikube profile list | grep -q "$PROFILE"; then
  echo "⚠️ Ya existe un perfil llamado '$PROFILE'."
  echo "Si fue iniciado previamente con otro montaje, podría fallar al reiniciarlo."

  if $AUTO_CONFIRM; then
    echo "🧹 Eliminando perfil automáticamente por opción -y..."
    minikube delete -p "$PROFILE"
  else
    read -rp "¿Querés eliminar el perfil y recrearlo? (s/n): " respuesta
    if [[ "$respuesta" == "s" || "$respuesta" == "S" ]]; then
      echo "Eliminando perfil existente '$PROFILE'..."
      minikube delete -p "$PROFILE"
    else
      echo "Abortado por el usuario. Elegí otro nombre de perfil si querés mantener el anterior."
      exit 1
    fi
  fi
fi

# --- CLONACIÓN DE REPOSITORIOS ---
[ -d "$LOCAL_WEB_DIR" ] || git clone "$REPO_WEB" "$LOCAL_WEB_DIR"
[ -d "$LOCAL_MANIFEST_DIR" ] || git clone "$REPO_MANIFESTS" "$LOCAL_MANIFEST_DIR"

# --- INICIAR MINIKUBE CON MONTAJE ---
echo "Iniciando Minikube con perfil: $PROFILE..." | tee -a "$LOG_FILE"
minikube start -p "$PROFILE" --driver=docker \
  --mount \
  --mount-string="${BASE_DIR}/${LOCAL_WEB_DIR}:${MOUNT_PATH}"

# --- APLICAR MANIFIESTOS ---
echo "Aplicando manifiestos de Kubernetes..." | tee -a "$LOG_FILE"
kubectl apply -f "$LOCAL_MANIFEST_DIR/volume/pv.yaml"
kubectl apply -f "$LOCAL_MANIFEST_DIR/volume/pvc.yaml"
kubectl apply -f "$LOCAL_MANIFEST_DIR/deployment/deployment.yaml"
kubectl apply -f "$LOCAL_MANIFEST_DIR/service/service.yaml"

# --- ESPERAR HASTA QUE EL POD ESTÉ EN ESTADO RUNNING ---
echo "Esperando que los pods estén en estado 'Running'..." | tee -a "$LOG_FILE"
MAX_RETRIES=20
SLEEP_TIME=5
RETRIES=0

while true; do
  READY_PODS=$(kubectl get pods --no-headers 2>/dev/null | grep web-static-git | grep Running | wc -l || true)
  if [ "$READY_PODS" -ge 1 ]; then
    echo "✅ Pod en estado Running detectado." | tee -a "$LOG_FILE"
    break
  fi

  if [ "$RETRIES" -ge "$MAX_RETRIES" ]; then
    echo "❌ Tiempo de espera agotado. El pod no está corriendo. Revisá con 'kubectl describe pods' o 'kubectl logs'." | tee -a "$LOG_FILE"
    exit 1
  fi

  RETRIES=$((RETRIES + 1))
  echo "⌛ Esperando... ($RETRIES/$MAX_RETRIES)" | tee -a "$LOG_FILE"
  sleep "$SLEEP_TIME"
done

# --- VERIFICAR ESTADO Y EXPONER SERVICIO ---
echo "Verificando estado final de los pods..." | tee -a "$LOG_FILE"
kubectl get pods | tee -a "$LOG_FILE"

echo "Accediendo al servicio web localmente..." | tee -a "$LOG_FILE"
minikube service web-static-service -p "$PROFILE"

echo "✅ Despliegue completo. Log disponible en: $LOG_FILE"
