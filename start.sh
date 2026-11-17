#!/bin/bash

usage() {
    echo "Usage: $0 [options] [services...]"
    echo ""
    echo "Services: app (default: all)"
    echo ""
    echo "Options:"
    echo "  -b, --build     Force rebuild images (needs internet — not during the exam)"
    echo "  -d, --detach    Run in background"
    echo "  -s, --stop      Stop running containers"
    echo "  -r, --restart   Restart containers"
    echo "  -l, --logs      Show logs (combine with service names)"
    echo "  -c, --console   Run a Symfony console command in the container"
    echo "  --status        Show container status"
    echo "  -h, --help      Show this help"
    echo ""
    echo "Uses podman if installed, otherwise docker."
    echo "Override with CONTAINER_ENGINE=docker|podman."
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# --- Container engine detection -------------------------------------------
# Default: docker. If podman is installed, podman is used instead.
# Override with: CONTAINER_ENGINE=docker ./start.sh  (or =podman)
detect_engine() {
    if [[ -n "$CONTAINER_ENGINE" ]]; then
        ENGINE="$CONTAINER_ENGINE"
    elif command -v podman >/dev/null 2>&1; then
        ENGINE="podman"
    else
        ENGINE="docker"
    fi

    if ! command -v "$ENGINE" >/dev/null 2>&1; then
        echo "Error: '$ENGINE' is not installed." >&2
        exit 1
    fi
}

# Sets COMPOSE to the matching compose command for $ENGINE.
detect_compose() {
    if [[ "$ENGINE" == "podman" ]]; then
        # Prefer podman-compose directly: 'podman compose' may delegate to
        # docker-compose, which would talk to the Docker daemon instead.
        if command -v podman-compose >/dev/null 2>&1; then
            COMPOSE=(podman-compose)
        elif podman compose version >/dev/null 2>&1; then
            COMPOSE=(podman compose)
        else
            echo "Error: podman-compose is not installed (e.g. 'sudo apt install podman-compose')." >&2
            exit 1
        fi

        if [[ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" == "true" ]]; then
            # Rootless podman: Apache runs as www-data (uid 1000). 'keep-id'
            # maps that uid to the host user, so var/ and vendor/ written by
            # the container stay editable on the host. keep-id also makes the
            # host user the default container user, but the entrypoint must
            # run as root (chown, Apache binding :80) — hence -u 0:0.
            # Passed as run args instead of a second compose file: with more
            # than one file podman-compose dumps the whole merged config.
            COMPOSE+=(--podman-run-args "--userns keep-id -u 0:0")

            # Rootless podman cannot bind ports < 1024 (unless allowed by sysctl).
            local min_port
            min_port="$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || echo 1024)"
            if [[ -z "$HTTP_PORT" && "$min_port" -gt 80 ]]; then
                export HTTP_PORT=8080
                echo "Note: rootless podman cannot use port 80, the app runs on http://localhost:8080 (override with HTTP_PORT=...)."
            fi
        fi
    else
        if docker compose version >/dev/null 2>&1; then
            COMPOSE=(docker compose)
        elif command -v docker-compose >/dev/null 2>&1; then
            COMPOSE=(docker-compose)
        else
            echo "Error: docker compose is not installed." >&2
            exit 1
        fi
    fi
}

ACTION="up"
BUILD=""
DETACH=""
SERVICES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)   BUILD="--build"; shift ;;
        -d|--detach)  DETACH="-d"; shift ;;
        -s|--stop)    ACTION="stop"; shift ;;
        -r|--restart) ACTION="restart"; shift ;;
        -l|--logs)    ACTION="logs"; shift ;;
        -c|--console) ACTION="console"; shift; break ;;
        --status)     ACTION="status"; shift ;;
        -h|--help)    usage; exit 0 ;;
        app)          SERVICES="$SERVICES $1"; shift ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Rebuilding re-runs apt-get inside the Dockerfile, which needs a working
# internet connection. During the exam there is none, and a half-finished build
# leaves the student without an environment. Plain ./start.sh never builds: the
# image is already there, either built beforehand or loaded from a .tar.
if [ -n "$BUILD" ] && [ "${ALLOW_BUILD:-}" != "1" ]; then
    echo "Refusing to rebuild the image."
    echo ""
    echo "Rebuilding downloads system packages and needs internet. During the exam"
    echo "there is none, and a failed rebuild leaves you without a working setup."
    echo ""
    echo "You almost certainly just want:"
    echo "    ./start.sh"
    echo ""
    echo "If you really do need to rebuild and you have internet:"
    echo "    ALLOW_BUILD=1 ./start.sh -b"
    exit 1
fi

detect_engine
detect_compose
echo "==> Using $ENGINE (${COMPOSE[*]})"

# podman-compose does not recreate existing containers on --build,
# so the freshly built image would not be used without --force-recreate.
if [[ "$ENGINE" == "podman" && -n "$BUILD" ]]; then
    BUILD="$BUILD --force-recreate"
fi

# Console commands run as www-data, the same user Apache uses, so the cache
# they write stays writable for the web server (and, under rootless podman,
# for the host user). Without a TTY (scripts, CI) exec needs -T; podman-compose
# would otherwise always request one and fail.
EXEC_OPTS=(--user www-data)
[ -t 0 ] || EXEC_OPTS+=(-T)

case $ACTION in
    up)      "${COMPOSE[@]}" -f "$COMPOSE_FILE" up $BUILD $DETACH $SERVICES ;;
    stop)    "${COMPOSE[@]}" -f "$COMPOSE_FILE" stop $SERVICES ;;
    restart) "${COMPOSE[@]}" -f "$COMPOSE_FILE" restart $SERVICES ;;
    logs)    "${COMPOSE[@]}" -f "$COMPOSE_FILE" logs -f $SERVICES ;;
    status)  "${COMPOSE[@]}" -f "$COMPOSE_FILE" ps ;;
    console) "${COMPOSE[@]}" -f "$COMPOSE_FILE" exec "${EXEC_OPTS[@]}" app php bin/console "$@" ;;
esac
