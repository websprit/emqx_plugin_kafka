#!/bin/bash
set -e

# Define image (Erlang 26 for EMQX 5.4)
IMAGE="erlang:26.2.5"

# Run build in Docker (Force x86/AMD64 architecture)
# We use --platform linux/amd64 to ensure the output works on your x86 Linux server
# independent of whether your Mac is Intel or Apple Silicon.
docker run --rm --platform linux/amd64 -v "$(pwd):/app" -w /app $IMAGE bash -c "
    echo 'Building in Linux environment...'
    # Clean previous builds to avoid mixing OS artifacts
    rm -rf _build
    
    # Ensure rebar3 is executable
    chmod +x get-rebar3
    ./get-rebar3 3.19.0-emqx-1
    chmod +x rebar3
    
    # Compile
    make rel
"

echo "Build complete. Linux-compatible package:"
ls -l _build/default/emqx_plugrel/*.tar.gz
