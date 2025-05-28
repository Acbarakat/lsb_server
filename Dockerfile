# Stage 1: Build stage
# Shared base image for setup
FROM ubuntu:25.10 AS base

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /server

RUN apt update && \
    apt upgrade -y && \
    apt install -y libzmq3-dev luarocks python3-dev libmariadb-dev git

FROM base AS builder

# Base dependencies for building
RUN apt install -y \
    software-properties-common \
    cmake make \
    libluajit-5.1-dev libssl-dev zlib1g-dev binutils-dev \
    g++ ccache

# Copy Build files
COPY cmake/ cmake/
COPY ext/ ext/
COPY res/ res/
COPY src/ src/
COPY modules/ modules/
COPY tools/generate_ipc_stubs.py tools/*.cpp tools/
COPY CMakeLists.txt CMakeSettings.json ./

# Build C++ code with build cache
RUN --mount=type=cache,target=/cmake-cache,id=cmake-cache \
    --mount=type=cache,target=/ccache,id=ccache-cache \
    ccache --set-config=cache_dir=/ccache && \
    cmake -S . -B /cmake-cache -DCACHE_OPTION=ccache && \
    cmake --build /cmake-cache -j $(nproc)


# Stage 2: Final runtime image
FROM base AS runtime

# Minimal runtime dependencies only
RUN apt install -y \
    python3-poetry \
    libluajit-5.1-2 libssl3 zlib1g mariadb-client && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user and group
RUN groupadd --system xi && useradd --system --gid xi --create-home --home-dir /home/xi xi

# Poetry configuration
RUN poetry config virtualenvs.create false && \
    poetry config cache-dir /poetry-cache

# Copy pyproject and install Python dependencies
COPY tools/poetry.lock tools/pyproject.toml ./
RUN --mount=type=cache,target=/poetry-cache,id=poetry-deps-cache \
    poetry install --without dev --no-root --compile && \
    rm poetry.lock pyproject.toml

# Copy final built binary/artifacts from builder
COPY --from=builder /server/xi_* /server/
# This is needed for map server
COPY --from=builder /server/res/compress.dat /server/res/decompress.dat /server/res/
# Set ownership of /server to the non-root user
RUN chown -R xi:xi /server

COPY --chown=xi:xi ./scripts/ scripts/
COPY --chown=xi:xi ./tools/ tools/
COPY --chown=xi:xi ./entry.sh .

# Set permissions for scripts
RUN chmod +x ./tools/dbtool.py \
    && chmod +x ./entry.sh

# Switch to non-root user
USER xi

ENTRYPOINT ["/server/entry.sh"]
