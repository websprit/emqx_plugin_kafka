# syntax=docker/dockerfile:1.7

FROM --platform=$TARGETPLATFORM erlang:26.2.5 AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /app

COPY Makefile rebar.config get-rebar3 ./
COPY rebar.lock ./

RUN chmod +x get-rebar3 \
    && ./get-rebar3 3.19.0-emqx-1 \
    && chmod +x rebar3

# Fetch dependencies before copying the rest of the source tree to maximize cache reuse.
RUN retry() { \
      local max_attempts="$1"; shift; \
      local attempt=1; \
      until "$@"; do \
        if [ "$attempt" -ge "$max_attempts" ]; then \
          echo "Command failed after ${attempt} attempts: $*"; \
          return 1; \
        fi; \
        echo "Command failed, retrying (${attempt}/${max_attempts}): $*"; \
        sleep $((attempt * 5)); \
        attempt=$((attempt + 1)); \
      done; \
    }; \
    retry 3 ./rebar3 get-deps

COPY src ./src
COPY include ./include
COPY priv ./priv
COPY LICENSE README.md erlang_ls.config ./

# Keep the dependency layer from `get-deps` so `make rel` can reuse it.
RUN retry() { \
      local max_attempts="$1"; shift; \
      local attempt=1; \
      until "$@"; do \
        if [ "$attempt" -ge "$max_attempts" ]; then \
          echo "Command failed after ${attempt} attempts: $*"; \
          return 1; \
        fi; \
        echo "Command failed, retrying (${attempt}/${max_attempts}): $*"; \
        sleep $((attempt * 5)); \
        attempt=$((attempt + 1)); \
      done; \
    }; \
    retry 3 make rel

FROM scratch AS artifact

COPY --from=build /app/_build/default/emqx_plugrel/*.tar.gz /
