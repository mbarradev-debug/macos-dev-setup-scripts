#!/usr/bin/env bash
# Author: Miguel Barra <mbarra.git@gmail.com>

# ============================
#  Folder configuration
# ============================

BASE="$HOME"
FORCAST_DIR="$BASE/forcast"
DOB_DIR="$BASE/dobvalidator"

# Descriptive subfolders
EHIVE_DIR="$FORCAST_DIR/ehive"
MICROSERVICES_DIR="$FORCAST_DIR/microservices"
ITSSOLUTIONS_DIR="$FORCAST_DIR/itssolutions"

# Create folders if they don't exist
mkdir -p "$EHIVE_DIR"
mkdir -p "$MICROSERVICES_DIR"
mkdir -p "$ITSSOLUTIONS_DIR"
mkdir -p "$DOB_DIR"

# ============================
#  Clone function
# ============================

clone_repo() {
  local repo_url="$1"
  local target_dir="$2"

  echo "Cloning $repo_url -> $target_dir"
  git clone "$repo_url" "$target_dir"
}

# ============================
#  E-Hive (App + Platform)
# ============================

clone_repo "git@github-work:forcast-lmtd/E-HivePlatform_v2.git" \
  "$EHIVE_DIR/E-HivePlatform_v2"

clone_repo "git@github-work:forcast-lmtd/E-HiveApp_v2.git" \
  "$EHIVE_DIR/E-HiveApp_v2"

# ============================
#  E-Hive microservices
# ============================

clone_repo "git@github-work:forcast-lmtd/ehive-server.git" \
  "$MICROSERVICES_DIR/ehive-server"

clone_repo "git@github-work:forcast-lmtd/ocpp-python.git" \
  "$MICROSERVICES_DIR/ocpp-python"

clone_repo "git@github-work:forcast-lmtd/ehive-gateway-mqtt.git" \
  "$MICROSERVICES_DIR/ehive-gateway-mqtt"

clone_repo "git@github-work:forcast-lmtd/ehive-local-databases.git" \
  "$MICROSERVICES_DIR/ehive-local-databases"

# ============================
#  IT Solutions (Dom Digital)
# ============================

clone_repo "git@github-work:forcast-lmtd/dom-digital.git" \
  "$ITSSOLUTIONS_DIR/dom-digital"

# ============================
#  Dobvalidator repos
# ============================

clone_repo "git@github-work:Dobprotocol/DOBVALIDATOR.git" \
  "$DOB_DIR/DOBVALIDATOR"

clone_repo "git@github-work:Dobprotocol/DOB_LANDING.git" \
  "$DOB_DIR/DOB_LANDING"

clone_repo "git@github-work:Dobprotocol/Doblink.git" \
  "$DOB_DIR/Doblink"

echo "==========================================="
echo "   All repos were cloned"
echo "   Base location: $HOME"
echo "==========================================="
