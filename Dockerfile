FROM postgres:16

ENV POSTGRES_DB=ecommerce
ENV POSTGRES_USER=app
ENV POSTGRES_PASSWORD=app_password

# Runs once on first container start against an empty data directory
COPY ./db/schema.sql /docker-entrypoint-initdb.d/schema.sql

EXPOSE 5432

HEALTHCHECK --interval=5s --timeout=5s --retries=10 \
  CMD pg_isready -U app -d ecommerce

VOLUME ["/var/lib/postgresql/data"]