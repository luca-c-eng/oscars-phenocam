#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# oscars-phenocam — Automated Installation Script
# =============================================================================
# Usage (run as any user with sudo privileges):
#
#  curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v1.7.0/install.sh | bash
#
# Optional:
#
#  curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v1.7.0/install.sh -o install.sh
#  PHENOCAM_DISABLE_TIMERS=1 bash install.sh
#
# What this script does:
#   1. Checks prerequisites (OS, hardware, network)
#   2. Installs system dependencies (git, exiftool)
#   3. Clones or updates the repository from GitHub
#   4. Verifies all expected critical files are present
#   5. Enables the camera interface if needed
#   6. Deploys the software to system directories
#   7. Creates configuration file templates without overwriting existing config
#   8. Installs systemd units, logrotate config and udev rules
#   9. Prepares RAMDISK and enables production timers for boot
#  10. Reports installation status and next actions
#
# After installation, configure:
#   sudo nano /etc/phenocam/settings.txt
#   sudo nano /etc/phenocam/ftp_credentials.txt
#
# Normal flow:
#   install -> configure -> reboot -> timers start automatically at boot
# =============================================================================

# ── Constants ─────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/luca-c-eng/oscars-phenocam.git"
REPO_BRANCH="dev/v1.7.0"
INSTALL_DIR="/opt/oscars-phenocam"
SOFTWARE_DIR="${INSTALL_DIR}/software"
LIB_DIR="/usr/local/lib/phenocam"
CONFIG_DIR="/etc/phenocam"
LOG_DIR="/var/log/phenocam"
SYSTEMD_DIR="/etc/systemd/system"
UDEV_DIR="/etc/udev/rules.d"

# Pinned dependency versions (tested and verified)
EXIFTOOL_VERSION="13.25+dfsg-1"
EXPECTED_FILE_COUNT=46

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

# ── Helpers ───────────────────────────────────────────────────────────────────
log_step()  { echo -e "\n${BLUE}${BOLD}▶ $*${NC}"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $*"; }
log_err()   { echo -e "  ${RED}✗${NC} $*"; }
log_fatal() { echo -e "\n${RED}${BOLD}FATAL: $*${NC}\n"; exit 1; }

# ── Step 1 — Prerequisites ────────────────────────────────────────────────────
log_step "Checking prerequisites..."

# Must not run as root
[[ "$EUID" -ne 0 ]] || log_fatal "Do not run this script as root. Run as a regular user with sudo privileges."

# Must have sudo; this may ask for the password once.
sudo -v || log_fatal "This script requires sudo privileges."

# Check OS
if grep -q "trixie" /etc/os-release 2>/dev/null; then
  log_ok "OS: Debian 13 trixie (Raspberry Pi OS)"
else
  log_warn "Unexpected OS version. This script was tested on Debian 13 trixie."
  log_warn "Proceeding, but some steps may fail."
fi

# Check architecture
ARCH="$(uname -m)"
if [[ "$ARCH" == "aarch64" ]]; then
  log_ok "Architecture: aarch64 (64-bit ARM)"
else
  log_warn "Unexpected architecture: $ARCH. Expected aarch64."
fi

# Check network
if ip route get 1.1.1.1 >/dev/null 2>&1; then
  log_ok "Network: internet connectivity confirmed"
else
  log_fatal "No internet connectivity. Connect the RPi to the network and retry."
fi

# ── Step 2 — Install dependencies ────────────────────────────────────────────
log_step "Installing system dependencies..."

sudo apt-get update -qq

# Install git
if ! command -v git >/dev/null 2>&1; then
  sudo apt-get install -y git
  log_ok "git installed"
else
  log_ok "git already present: $(git --version)"
fi

# Install exiftool at pinned version where available.
INSTALLED_EXIFTOOL="$(dpkg-query -W -f='${Version}' libimage-exiftool-perl 2>/dev/null || true)"
if [[ "$INSTALLED_EXIFTOOL" == "$EXIFTOOL_VERSION" ]]; then
  log_ok "exiftool already at pinned version: $EXIFTOOL_VERSION"
else
  sudo apt-get install -y "libimage-exiftool-perl=${EXIFTOOL_VERSION}" || {
    log_warn "Pinned version $EXIFTOOL_VERSION not available. Installing latest available..."
    sudo apt-get install -y libimage-exiftool-perl
  }

  INSTALLED_EXIFTOOL="$(dpkg-query -W -f='${Version}' libimage-exiftool-perl 2>/dev/null || true)"
  log_ok "exiftool installed: $INSTALLED_EXIFTOOL"

  if [[ "$INSTALLED_EXIFTOOL" != "$EXIFTOOL_VERSION" ]]; then
    log_warn "Installed version ($INSTALLED_EXIFTOOL) differs from pinned ($EXIFTOOL_VERSION)."
    log_warn "Software will likely work, but report this for future VERSIONS.txt update."
  fi
fi

# Freeze exiftool version if installed.
if dpkg-query -W libimage-exiftool-perl >/dev/null 2>&1; then
  sudo apt-mark hold libimage-exiftool-perl >/dev/null
  log_ok "exiftool version frozen (apt-mark hold)"
fi

# Verify other required tools.
for tool in rpicam-still curl sftp flock; do
  if command -v "$tool" >/dev/null 2>&1; then
    log_ok "$tool: $(command -v "$tool")"
  else
    log_fatal "$tool not found. Is this Raspberry Pi OS Lite (64-bit)?"
  fi
done

# Verify runuser path.
if [[ -x /usr/sbin/runuser ]]; then
  log_ok "runuser: /usr/sbin/runuser"
else
  log_fatal "runuser not found at /usr/sbin/runuser."
fi

# ── Step 3 — Clone or update repository ───────────────────────────────────────
log_step "Cloning/updating repository..."

if [[ -d "$INSTALL_DIR/.git" ]]; then
  log_warn "Repository already exists at $INSTALL_DIR. Updating branch ${REPO_BRANCH}..."
  sudo git -C "$INSTALL_DIR" fetch origin "$REPO_BRANCH"
  sudo git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
  sudo git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"
else
  sudo git clone --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

log_ok "Repository ready at: $INSTALL_DIR"

# ── Step 4 — Verify downloaded files ─────────────────────────────────────────
log_step "Verifying downloaded files..."

ACTUAL_COUNT="$(find "$INSTALL_DIR" -type f | wc -l)"
if [[ "$ACTUAL_COUNT" -ge "$EXPECTED_FILE_COUNT" ]]; then
  log_ok "File count: $ACTUAL_COUNT (expected >= $EXPECTED_FILE_COUNT)"
else
  log_fatal "File count mismatch: found $ACTUAL_COUNT, expected $EXPECTED_FILE_COUNT. Clone may be incomplete."
fi

# Verify critical files exist.
CRITICAL_FILES=(
  "${SOFTWARE_DIR}/bin/phenocam-capture.sh"
  "${SOFTWARE_DIR}/bin/phenocam-upload.sh"
  "${SOFTWARE_DIR}/bin/phenocam-run.sh"
  "${SOFTWARE_DIR}/bin/phenocam-init-ramdisk.sh"
  "${SOFTWARE_DIR}/bin/phenocam-usb-attach.sh"
  "${SOFTWARE_DIR}/bin/phenocam-usb-detach.sh"

  "${SOFTWARE_DIR}/scripts/common.sh"
  "${SOFTWARE_DIR}/scripts/config_read.sh"
  "${SOFTWARE_DIR}/scripts/cycle.sh"
  "${SOFTWARE_DIR}/scripts/meta_build.sh"
  "${SOFTWARE_DIR}/scripts/queue_manager.sh"
  "${SOFTWARE_DIR}/scripts/upload_sftp.sh"
  "${SOFTWARE_DIR}/scripts/upload_ftp.sh"
  "${SOFTWARE_DIR}/scripts/uploader_daemon.sh"

  "${SOFTWARE_DIR}/config/phenocam.logrotate"

  "${SOFTWARE_DIR}/systemd/phenocam-init.service"
  "${SOFTWARE_DIR}/systemd/phenocam-capture.service"
  "${SOFTWARE_DIR}/systemd/phenocam-upload.service"
  "${SOFTWARE_DIR}/systemd/run-phenocam.mount"
  "${SOFTWARE_DIR}/systemd/phenocam-capture.timer"
  "${SOFTWARE_DIR}/systemd/phenocam-upload.timer"
  "${SOFTWARE_DIR}/systemd/99-phenocam-usb.rules"
  # next two lines added in v1.5.0 to check the temperature of the board.
  "${SOFTWARE_DIR}/scripts/system_health.sh" 
  "${SOFTWARE_DIR}/bin/diag_system_health.sh"
   # next two lines added in v1.6.0 to test full cicle at first start.
  "${SOFTWARE_DIR}/bin/phenocam-startup-cycle.sh"
  "${SOFTWARE_DIR}/systemd/phenocam-startup-cycle.service"
  "${SOFTWARE_DIR}/systemd/phenocam-startup-cycle.timer"
)

for f in "${CRITICAL_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    log_ok "Found: $(basename "$f")"
  else
    log_fatal "Critical file missing: $f"
  fi
done

# ── Step 5 — Enable camera ────────────────────────────────────────────────────
log_step "Enabling camera interface..."

# vcgencmd get_camera is kept as a lightweight compatibility check.
# On newer Raspberry Pi OS releases, diag_camera.sh/rpicam-hello are more useful
# after reboot.
if vcgencmd get_camera 2>/dev/null | grep -q "detected=1"; then
  log_ok "Camera currently detected"
else
  sudo raspi-config nonint do_camera 0 2>/dev/null || true
  log_warn "Camera was requested/enabled via raspi-config where supported."
  log_warn "A reboot may be required before the camera is detected."
  log_warn "After reboot, run: sudo /usr/local/lib/phenocam/bin/diag_camera.sh"
fi

# ── Step 5b — Detect hardware board ───────────────────────────────────────────
log_step "Detecting hardware board..."

BOARD_RAW="$(grep -i "Model" /proc/cpuinfo | tail -1 || true)"
if echo "$BOARD_RAW" | grep -qi "Zero 2"; then
  DETECTED_BOARD="rpizero2w"
elif echo "$BOARD_RAW" | grep -qi "3 Model B Plus\|3B+"; then
  DETECTED_BOARD="rpi3b+"
else
  DETECTED_BOARD="unknown"
  log_warn "Board not recognised: $BOARD_RAW — writing 'unknown' to settings.txt"
fi

log_ok "Board detected: $DETECTED_BOARD ($BOARD_RAW)"

# ── Step 6 — Deploy software ──────────────────────────────────────────────────
log_step "Deploying software..."

# Create system user.
if id phenocam >/dev/null 2>&1; then
  log_ok "User phenocam already exists"
else
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin phenocam
  log_ok "User phenocam created (uid=$(id -u phenocam))"
fi

# Add phenocam to video group.
sudo usermod -aG video phenocam
log_ok "phenocam added to video group"

# Create directory structure.
sudo mkdir -p \
  "${LIB_DIR}/bin" \
  "${LIB_DIR}/scripts" \
  "${LIB_DIR}/docs" \
  "${CONFIG_DIR}/keys" \
  "${LOG_DIR}" \
  "/var/lib/phenocam/queue"

log_ok "Directory structure created"

# Set config directory group before creating config files.
sudo chown -R root:phenocam "${CONFIG_DIR}"
log_ok "Config directory group set to phenocam"

# Copy scripts.
sudo cp "${SOFTWARE_DIR}/scripts/"*.sh "${LIB_DIR}/scripts/"
sudo cp "${SOFTWARE_DIR}/bin/"*.sh     "${LIB_DIR}/bin/"
sudo chmod +x "${LIB_DIR}/bin/"*.sh "${LIB_DIR}/scripts/"*.sh
log_ok "Scripts deployed and made executable ($(find "${LIB_DIR}" -name "*.sh" | wc -l) files)"

# Copy local documentation if present.
if [[ -d "${SOFTWARE_DIR}/docs" ]]; then
  sudo cp -r "${SOFTWARE_DIR}/docs/." "${LIB_DIR}/docs/"
fi

for doc in README.md ReadME.txt CHANGELOG.md VERSIONS.txt VERSION; do
  [[ -f "${SOFTWARE_DIR}/${doc}" ]] && sudo cp "${SOFTWARE_DIR}/${doc}" "${LIB_DIR}/docs/"
done

sudo chmod -R a+rX "${LIB_DIR}/docs"
log_ok "Documentation deployed to ${LIB_DIR}/docs"

# Note: Install runtime version marker and Install runtime build information added in v1.6.0

# Install runtime version marker.
if [[ -f "${SOFTWARE_DIR}/VERSION" ]]; then
  sudo cp "${SOFTWARE_DIR}/VERSION" "${LIB_DIR}/VERSION"
  sudo chmod 644 "${LIB_DIR}/VERSION"
  log_ok "Runtime VERSION installed to ${LIB_DIR}/VERSION"
fi

# Install runtime build information.
SOFTWARE_VERSION="$(tr -d '\r\n' < "${SOFTWARE_DIR}/VERSION" 2>/dev/null || echo nd)"
SOFTWARE_COMMIT="$(git -C "${INSTALL_DIR}" rev-parse --short HEAD 2>/dev/null || echo nd)"

{
  echo "software_name=oscars-phenocam"
  echo "software_version=${SOFTWARE_VERSION}"
  echo "software_branch=${REPO_BRANCH}"
  echo "software_commit=${SOFTWARE_COMMIT}"
  echo "installed_at=$(date -Is)"
} | sudo tee "${LIB_DIR}/BUILD_INFO" >/dev/null
sudo chmod 644 "${LIB_DIR}/BUILD_INFO"
log_ok "Runtime BUILD_INFO installed to ${LIB_DIR}/BUILD_INFO"

# Set permissions.
sudo chmod 750 \
  "${CONFIG_DIR}" \
  "${CONFIG_DIR}/keys" \
  "${LOG_DIR}" \
  "/var/lib/phenocam" \
  "/var/lib/phenocam/queue"

sudo chown phenocam:phenocam \
  "${LOG_DIR}" \
  "/var/lib/phenocam" \
  "/var/lib/phenocam/queue"

log_ok "Permissions set"

# ── Step 7 — Create configuration templates ───────────────────────────────────
log_step "Creating configuration files..."

# settings.txt — create only if not already present.
if ! sudo test -f "${CONFIG_DIR}/settings.txt"; then
  sudo tee "${CONFIG_DIR}/settings.txt" >/dev/null <<'SETTINGS'
mysite
+1
Europe/Rome
6
22
30
auto
phenocam
auto
20
80
/media:/mnt
90
general
nd
nd
nd
nd
nd
nd
unknown
imx708
30000
SETTINGS

  log_ok "settings.txt created (edit to set your SITENAME and parameters)"
  log_warn "ACTION REQUIRED: sudo nano ${CONFIG_DIR}/settings.txt — set SITENAME (line 1)"

  # Write auto-detected board into settings.txt (line 21).
  sudo sed -i "21s/.*/${DETECTED_BOARD:-unknown}/" "${CONFIG_DIR}/settings.txt"

  # Network interface is not derived from the Raspberry Pi model.
  # IFACE=auto lets runtime networking follow the active/default route.

  log_ok "Board written to settings.txt: ${DETECTED_BOARD:-unknown}"
else
  log_ok "settings.txt already exists — not overwritten"
fi

# server.txt — empty placeholder for SFTP.
if ! sudo test -f "${CONFIG_DIR}/server.txt"; then
  sudo touch "${CONFIG_DIR}/server.txt"
  log_ok "server.txt created (empty — SFTP disabled)"
else
  log_ok "server.txt already exists — not overwritten"
fi

# ftp_credentials.txt — comment-only placeholder.
if [[ ! -f "${CONFIG_DIR}/ftp_credentials.txt" ]]; then
  sudo tee "${CONFIG_DIR}/ftp_credentials.txt" >/dev/null <<'FTP'
# FTP credentials — one value per line, uncomment only after configuration.
# 1) FTP_HOST        e.g. 5.249.152.25
# 2) FTP_PORT        e.g. 21, or provider-defined FTP port such as 22
# 3) FTP_REMOTE_BASE e.g. /phenocams/data
# 4) FTP_USER
# 5) FTP_PASS
FTP

  log_ok "ftp_credentials.txt created (comment-only — FTP disabled until configured)"
  log_warn "ACTION REQUIRED: sudo nano ${CONFIG_DIR}/ftp_credentials.txt — set real FTP credentials"
else
  log_ok "ftp_credentials.txt already exists — not overwritten"
fi

# known_hosts — empty placeholder for SFTP.
if [[ ! -f "${CONFIG_DIR}/known_hosts" ]]; then
  sudo touch "${CONFIG_DIR}/known_hosts"
  log_ok "known_hosts created (empty)"
else
  log_ok "known_hosts already exists — not overwritten"
fi

# Configuration files must be readable by phenocam but not world-readable.
sudo chown root:phenocam \
  "${CONFIG_DIR}/settings.txt" \
  "${CONFIG_DIR}/server.txt" \
  "${CONFIG_DIR}/ftp_credentials.txt" \
  "${CONFIG_DIR}/known_hosts"

sudo chmod 640 \
  "${CONFIG_DIR}/settings.txt" \
  "${CONFIG_DIR}/server.txt" \
  "${CONFIG_DIR}/ftp_credentials.txt" \
  "${CONFIG_DIR}/known_hosts"

log_ok "Configuration file permissions set (root:phenocam, 640)"

# Generate SSH key pair for SFTP only if not already present.
if [[ ! -f "${CONFIG_DIR}/keys/phenocam_key" ]]; then
  sudo ssh-keygen -t ed25519 \
    -f "${CONFIG_DIR}/keys/phenocam_key" \
    -N "" \
    -C "phenocam@$(hostname)" \
    -q

  log_ok "SSH key pair generated: ${CONFIG_DIR}/keys/phenocam_key"
else
  log_ok "SSH key pair already exists — not regenerated"
fi

# Ensure the upload service user can read the SSH key pair.
sudo chown phenocam:phenocam \
  "${CONFIG_DIR}/keys/phenocam_key" \
  "${CONFIG_DIR}/keys/phenocam_key.pub"

sudo chmod 600 "${CONFIG_DIR}/keys/phenocam_key"
sudo chmod 644 "${CONFIG_DIR}/keys/phenocam_key.pub"

log_ok "SSH key permissions aligned for user phenocam"

log_ok "SSH public key (send to SFTP server administrator if using SFTP):"
echo ""
sudo cat "${CONFIG_DIR}/keys/phenocam_key.pub"
echo ""

# ── Step 8 — Install systemd units and udev rules ─────────────────────────────
log_step "Installing systemd units and udev rules..."

# Copy systemd units.
for unit in "${SOFTWARE_DIR}/systemd/"*.service \
            "${SOFTWARE_DIR}/systemd/"*.timer \
            "${SOFTWARE_DIR}/systemd/"*.mount; do
  [[ -f "$unit" ]] || continue
  sudo cp "$unit" "${SYSTEMD_DIR}/"
  log_ok "Installed: $(basename "$unit")"
done

# Install logrotate configuration.
if [[ -f "${SOFTWARE_DIR}/config/phenocam.logrotate" ]]; then
  sudo cp "${SOFTWARE_DIR}/config/phenocam.logrotate" /etc/logrotate.d/phenocam
  sudo chmod 644 /etc/logrotate.d/phenocam
  log_ok "logrotate configuration installed: /etc/logrotate.d/phenocam"
else
  log_warn "phenocam.logrotate not found — log rotation not installed"
fi

# Install udev rule.
sudo cp "${SOFTWARE_DIR}/systemd/99-phenocam-usb.rules" "${UDEV_DIR}/"
sudo udevadm control --reload-rules
log_ok "udev rule installed and reloaded (USB hot-plug enabled)"

# Reload systemd.
sudo systemctl daemon-reload
log_ok "systemd daemon reloaded"

# ── Step 9 — Enable runtime RAMDISK init and production timers ────────────────
log_step "Enabling PhenoCam RAMDISK init..."

sudo systemctl enable --now phenocam-init.service
log_ok "phenocam-init.service: enabled and started (RAMDISK prepared)"

# Check init result.
if systemctl is-failed phenocam-init.service >/dev/null 2>&1; then
  log_err "phenocam-init.service failed. Check:"
  log_err "  sudo journalctl -u phenocam-init.service -n 120 --no-pager"
else
  log_ok "phenocam-init.service completed successfully"
fi

# Enable production timers by default, but do not force an immediate run here.
# This restores the v1.3.x behaviour: after installation/configuration/reboot,
# the system starts capture/upload cycles automatically.
if [[ "${PHENOCAM_DISABLE_TIMERS:-0}" == "1" ]]; then
  sudo systemctl disable --now \
    phenocam-startup-cycle.timer \
    phenocam-capture.timer \
    phenocam-upload.timer >/dev/null 2>&1 || true

  log_warn "Production timers disabled because PHENOCAM_DISABLE_TIMERS=1"
  log_warn "Enable later with:"
  log_warn "  sudo systemctl enable --now phenocam-startup-cycle.timer phenocam-capture.timer phenocam-upload.timer"
else
  sudo systemctl enable \
    phenocam-startup-cycle.timer \
    phenocam-capture.timer \
    phenocam-upload.timer

  log_ok "phenocam-startup-cycle.timer enabled for boot test cycle"
  log_ok "phenocam-capture.timer enabled for boot (regular capture cycles)"
  log_ok "phenocam-upload.timer enabled for boot (regular upload cycles)"
  log_warn "Timers are enabled for the next boot. They are not forced to run immediately by the installer."
fi

# ── Step 10 — Final report ────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Installation complete — PhenoCam v$(cat "${SOFTWARE_DIR}/VERSION")${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Log:${NC}    sudo cat /var/log/phenocam/phenocam.log | tail -20"
echo -e "  ${BOLD}Status:${NC} sudo systemctl status phenocam-init.service phenocam-startup-cycle.timer phenocam-capture.timer phenocam-upload.timer"
echo -e "  ${BOLD}Camera:${NC} sudo /usr/local/lib/phenocam/bin/diag_camera.sh"
echo -e "  ${BOLD}Upload:${NC} sudo /usr/local/lib/phenocam/bin/diag_upload.sh"
echo -e "  ${BOLD}Health:${NC} sudo /usr/local/lib/phenocam/bin/diag_system_health.sh"
echo -e "  ${BOLD}Build:${NC}  cat /usr/local/lib/phenocam/BUILD_INFO"
echo ""

# Remind about required configuration.
echo -e "${YELLOW}${BOLD}  Required actions before the system can upload images:${NC}"
echo -e "${YELLOW}  1. Set station name and timing/network parameters:${NC}"
echo -e "${GREEN}     sudo nano /etc/phenocam/settings.txt${NC}"
echo -e "${YELLOW}     Edit SITENAME on line 1 at minimum.${NC}"
echo ""
echo -e "${YELLOW}  Choose your upload protocol:${NC}"
echo ""
echo -e "${YELLOW}  FTP — edit credentials:${NC}"
echo -e "${GREEN}     sudo nano /etc/phenocam/ftp_credentials.txt${NC}"
echo -e "${YELLOW}     FTP port is configurable; use your provider value, even if it is 22.${NC}"
echo ""
echo -e "${YELLOW}  SFTP — SSH key, no password over network:${NC}"
echo -e "${GREEN}     1. Send the public key printed above to your SFTP server administrator${NC}"
echo -e "${GREEN}     2. sudo nano /etc/phenocam/server.txt  (add one or more server hostnames)${NC}"
echo -e "${GREEN}     3. sudo ssh-keyscan -H <hostname> | sudo tee -a /etc/phenocam/known_hosts >/dev/null${NC}"
echo -e "${GREEN}     4. Edit line 8 of settings.txt (SFTP_USER)${NC}"
echo -e "${GREEN}     5. Edit line 14 of settings.txt (REMOTE_LAYOUT: general or icos)${NC}"
echo ""
echo -e "${YELLOW}  Production timers:${NC}"
echo -e "${GREEN}     Already enabled for boot by default.${NC}"
echo -e "${GREEN}     Normal flow: configure files, then reboot.${NC}"
echo -e "${GREEN}     Check boot enable state:${NC}"
echo -e "${GREEN}     systemctl is-enabled phenocam-startup-cycle.timer phenocam-capture.timer phenocam-upload.timer${NC}"
echo -e "${GREEN}     Check next runs:${NC}"
echo -e "${GREEN}     systemctl list-timers 'phenocam-*' --all${NC}"
echo -e "${GREEN}     Run startup test cycle immediately:${NC}"
echo -e "${GREEN}     sudo systemctl start phenocam-startup-cycle.service${NC}"
echo -e "${GREEN}     Start regular timers immediately without reboot:${NC}"
echo -e "${GREEN}     sudo systemctl start phenocam-capture.timer phenocam-upload.timer${NC}"
echo -e "${GREEN}     To disable automatic operation:${NC}"
echo -e "${GREEN}     sudo systemctl disable --now phenocam-startup-cycle.timer phenocam-capture.timer phenocam-upload.timer${NC}"
echo ""

# Check if reboot may be needed.
if vcgencmd get_camera 2>/dev/null | grep -q "detected=0"; then
  echo -e "${YELLOW}${BOLD}  ⚠  REBOOT MAY BE REQUIRED: camera is not currently detected.${NC}"
  echo -e "${YELLOW}     Run: sudo reboot${NC}"
  echo -e "${YELLOW}     After reboot, check: sudo /usr/local/lib/phenocam/bin/diag_camera.sh${NC}"
  echo ""
else
  echo -e "${YELLOW}${BOLD}  Recommended next step:${NC}"
  echo -e "${YELLOW}     If you have just configured settings/upload files, run: sudo reboot${NC}"
  echo -e "${YELLOW}     After reboot, timers should start automatically.${NC}"
  echo ""
fi
