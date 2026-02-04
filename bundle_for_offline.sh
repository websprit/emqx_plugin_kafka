#!/bin/bash
set -e

echo "=== 1. Preparing Environment on Mac ==="
# Ensure rebar3 is present (downloads from internet)
chmod +x get-rebar3
./get-rebar3 3.19.0-emqx-1
chmod +x rebar3

echo "=== 2. Fetching Dependencies (Internet Required) ==="
# Fetch all dependencies to _build/default/lib/
./rebar3 get-deps
./rebar3 compile  # Compile to ensure all hooks/plugins are fetched

echo "=== 3. Cleaning Mac-specific Binaries ==="
# We only want the source code of the dependencies, not the Mac-compiled binaries
# But we keep the folder structure
find _build -name "*.so" -delete
find _build -name "*.o" -delete
find _build -name "*.beam" -delete
find _build -name "*.dll" -delete
find _build -name "*.dylib" -delete

echo "=== 4. Bundling for Linux Server ==="
TAR_NAME="emqx_plugin_kafka_offline_src.tar.gz"
tar -czf "$TAR_NAME" \
    --exclude='.git' \
    --exclude='.idea' \
    --exclude='_build/default/rel' \
    ./*

echo ""
echo "✅ Bundle created: $TAR_NAME"
echo "---------------------------------------------------"
echo "Next Steps:"
echo "1. Upload '$TAR_NAME' to your Linux server (k8s-master)."
echo "2. Unzip it: tar -xzf $TAR_NAME"
echo "3. Run compilation: ./rebar3 emqx_plugrel tar"
echo "---------------------------------------------------"
