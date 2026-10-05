FROM ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine AS build
RUN apk add --no-cache build-base
WORKDIR /build
COPY gleam.toml manifest.toml ./
RUN gleam deps download
COPY src ./src
COPY priv ./priv
RUN gleam export erlang-shipment
COPY container/start.sh build/erlang-shipment/start
COPY container/migrate.sh build/erlang-shipment/migrate
COPY container/seed.sh build/erlang-shipment/seed

FROM erlang:29-alpine
RUN apk add --no-cache libstdc++ ca-certificates \
 && addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build --chown=app:app /build/build/erlang-shipment /app
USER app
ENV PORT=4000
EXPOSE 4000
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT}/health" >/dev/null || exit 1
ENTRYPOINT ["/bin/sh", "/app/start"]
