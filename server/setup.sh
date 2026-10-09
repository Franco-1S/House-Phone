#!/usr/bin/env bash
# =============================================================================
#  Haustelefon – Server-Setup (Raspberry Pi / jedes Linux mit Docker)
#
#    ./setup.sh            Konfiguration erzeugen + Asterisk (neu) starten
#    ./setup.sh check      nur haustelefon.yaml prüfen
#    ./setup.sh codes      Einrichtungscodes aller Geräte anzeigen
#    ./setup.sh status     Leitungen & Geräte live anzeigen
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFehler:\033[0m %s\n' "$*" >&2; exit 1; }

need_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    say "Docker fehlt – wird installiert (einmalig, braucht sudo) ..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER" || true
    say "Docker installiert. Bitte einmal ab- und wieder anmelden, dann ./setup.sh erneut starten."
    exit 0
  fi
  docker compose version >/dev/null 2>&1 || fail "'docker compose' fehlt (Docker zu alt?)"
}

# Generator: lokal mit Python+PyYAML, sonst in einem kleinen Container.
generate() {
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
    python3 generator/generate.py "$@"
  else
    need_docker
    docker run --rm -v "$PWD:/work" -w /work python:3.12-alpine \
      sh -c 'pip install -q --disable-pip-version-check pyyaml && python generator/generate.py "$@"' _ "$@"
  fi
}

[ -f haustelefon.yaml ] || {
  cp haustelefon.example.yaml haustelefon.yaml
  fail "haustelefon.yaml wurde aus der Vorlage angelegt – bitte anpassen (Speedport-Passwörter, Geräte) und ./setup.sh erneut starten."
}

case "${1:-up}" in
  check)
    generate --check
    ;;
  codes)
    shopt -s nullglob
    for f in generated/provisioning/*.txt; do
      printf '\n\033[1m%s\033[0m\n' "$(basename "$f" .txt)"; cat "$f"
    done
    ;;
  status)
    need_docker
    docker exec haustelefon-asterisk asterisk -rx "pjsip show registrations"
    docker exec haustelefon-asterisk asterisk -rx "pjsip show contacts"
    ;;
  up)
    generate
    need_docker
    # Vorgänger-Version (raspberry-pi/docker-compose.yml) belegt dieselben Ports.
    if docker ps -a --format '{{.Names}}' | grep -qx haustelefon-gateway; then
      say "Entferne alten Container haustelefon-gateway ..."
      docker rm -f haustelefon-gateway >/dev/null
    fi
    say "Starte Asterisk ..."
    docker compose up -d
    # Konfiguration neu laden, falls der Container schon lief.
    sleep 2
    docker exec haustelefon-asterisk asterisk -rx "core reload" >/dev/null 2>&1 || true
    say "Fertig. Status:            ./setup.sh status"
    say "Einrichtungscodes:         ./setup.sh codes"
    ;;
  *)
    fail "unbekannter Befehl '$1' (up | check | codes | status)"
    ;;
esac
