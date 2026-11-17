#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPORT_DIR="$SCRIPT_DIR/_images"

# --- Container engine detection -------------------------------------------
# Default: docker. If podman is installed, podman is used instead.
# Override with: CONTAINER_ENGINE=docker ./build.sh  (or =podman)
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

usage() {
    echo "Usage: $0 [options] [app|all]"
    echo ""
    echo "Builds the container image for the Symfony app."
    echo "Default target: all"
    echo ""
    echo "Options:"
    echo "  -c, --clean     Clean build (no cache)"
    echo "  -e, --export    Export built image as .tar file to _images/"
    echo "  -h, --help      Show this help"
    echo ""
    echo "Uses podman if installed, otherwise docker."
    echo "Override with CONTAINER_ENGINE=docker|podman."
}

build_app() {
    echo "==> Building Symfony image..."
    "$ENGINE" build $CLEAN -t webt-symfony "$SCRIPT_DIR"
    echo "==> Symfony image built successfully."
}

export_image() {
    local name="$1"
    mkdir -p "$EXPORT_DIR"
    echo "==> Exporting $name to $EXPORT_DIR/$name.tar ..."
    # podman refuses to overwrite an existing archive
    rm -f "$EXPORT_DIR/$name.tar"
    "$ENGINE" save -o "$EXPORT_DIR/$name.tar" "$name"
    echo "==> Exported $name ($(du -h "$EXPORT_DIR/$name.tar" | cut -f1))"
}

CLEAN=""
EXPORT=false
TARGET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)  CLEAN="--no-cache"; shift ;;
        -e|--export) EXPORT=true; shift ;;
        -h|--help)   usage; exit 0 ;;
        app|all)     TARGET="$1"; shift ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

TARGET="${TARGET:-all}"

detect_engine
echo "==> Using $ENGINE"

case "$TARGET" in
    app|all)
        build_app
        if $EXPORT; then export_image webt-symfony; fi
        ;;
esac
