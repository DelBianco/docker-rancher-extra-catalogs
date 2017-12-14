version: "2"

services:
  config:
    labels:
      io.rancher.container.pull_image: always
    image: eugenmayer/concourse-configurator
    volumes:
      {{- if .Values.WEB_KEYS_VOLUME_NAME}}
      - {{.Values.WEB_KEYS_VOLUME_NAME}}:/concourse-keys/web
      {{- else}}
      - concourse-keys-web:/concourse-keys/web
      {{- end }}

      {{- if .Values.WORKER_KEYS_VOLUME_NAME}}
      - {{.Values.WORKER_KEYS_VOLUME_NAME}}:/concourse-keys/worker
      {{- else}}
      - concourse-keys-worker:/concourse-keys/worker
      {{- end }}

      {{- if .Values.VAULT_CLIENT_CONFIG_VOLUME_NAME}}
      - {{.Values.VAULT_CLIENT_CONFIG_VOLUME_NAME}}:/vault/concourse
      {{- else}}
      - vault-client-config:/vault/concourse
      {{- end }}

      {{- if .Values.VAULT_SERVER_CONFIG_VOLUME_NAME}}
      - {{.Values.VAULT_SERVER_CONFIG_VOLUME_NAME}}:/vault/server
      {{- else}}
      - vault-server-config:/vault/server
      {{- end }}
    restart: unless-stopped
    environment:
      VAULT_ENABLED: 1
      VAULT_DO_AUTOCONFIGURE: 1
  vault:
    restart: unless-stopped # required so that it retries until conocurse-db comes up
    image: vault:0.9.0
    cap_add:
     - IPC_LOCK
    depends_on:
     - config
    command: vault server -config /vault/config/vault.hcl {{.Values.VAULT_START_PARAMS}}
    volumes:
      {{- if .Values.VAULT_SERVER_CONFIG_VOLUME_NAME}}
      - {{.Values.VAULT_SERVER_CONFIG_VOLUME_NAME}}:/vault/config
      {{- else}}
      - vault-server-config:/vault/config
      {{- end }}

      {{- if .Values.VAULT_SERVER_DATA_VOLUME_NAME}}
      - {{.Values.VAULT_SERVER_DATA_VOLUME_NAME}}:/vault/file
      {{- else}}
      - vault-server-data:/vault/file
      {{- end }}

  db:
    image: postgres:10.1
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      {{- if .Values.DB_VOLUME_NAME}}
      - {{.Values.DB_VOLUME_NAME}}:/var/lib/postgresql/data
      {{- else}}
      - pgdata:/var/lib/postgresql/data
      {{- end }}

  # see https://github.com/concourse/concourse-docker/blob/master/Dockerfile
  web:
    labels:
      io.rancher.container.pull_image: always
    image: concourse/concourse:3.7.0
    command: web --vault-ca-cert /vault/client/server.crt
    depends_on:
      - config
      - db
      - vault
    volumes:
      {{- if .Values.WEB_KEYS_VOLUME_NAME}}
      - {{.Values.WEB_KEYS_VOLUME_NAME}}:/concourse-keys
      {{- else}}
      - concourse-keys-web:/concourse-keys
      {{- end }}
      {{- if .Values.VAULT_CLIENT_CONFIG_VOLUME_NAME}}
      - {{.Values.VAULT_CLIENT_CONFIG_VOLUME_NAME}}:/vault/client
      {{- else}}
      - vault-client-config:/vault/client
      {{- end }}
    restart: unless-stopped # required so that it retries until conocurse-db comes up
    environment:
      CONCOURSE_BASIC_AUTH_USERNAME: ${ADMIN_USER}
      CONCOURSE_BASIC_AUTH_PASSWORD: ${ADMIN_PASSWORD}
      CONCOURSE_EXTERNAL_URL: ${CONCOURSE_EXTERNAL_URL}
      CONCOURSE_POSTGRES_HOST: db
      CONCOURSE_POSTGRES_USER: ${DB_USER}
      CONCOURSE_POSTGRES_PASSWORD: ${DB_PASSWORD}
      CONCOURSE_POSTGRES_DATABASE: ${DB_NAME}

      CONCOURSE_VAULT_URL: https://vault:8200
      CONCOURSE_VAULT_TLS_INSECURE_SKIP_VERIFY: "true"
      CONCOURSE_VAULT_AUTH_BACKEND: cert
      CONCOURSE_VAULT_PATH_PREFIX: /secret/concourse
      # those keys are generated by the config container
      CONCOURSE_VAULT_CLIENT_CERT: /vault/client/cert.pem
      CONCOURSE_VAULT_CLIENT_KEY: /vault/client/key.pem

  # see https://github.com/concourse/concourse-docker/blob/master/Dockerfile
  worker:
    labels:
      io.rancher.container.pull_image: always
    image: eugenmayer/concourse-worker-solid:3.8.0
    privileged: true
    depends_on:
      - config
      - web
    volumes:
      {{- if .Values.WORKER_KEYS_VOLUME_NAME}}
      - {{.Values.WORKER_KEYS_VOLUME_NAME}}:/concourse-keys
      {{- else}}
      - concourse-keys-worker:/concourse-keys
      {{- end }}
    environment:
      CONCOURSE_TSA_HOST: web
      CONCOURSE_GARDEN_NETWORK_POOL: ${CONCOURSE_GARDEN_NETWORK_POOL}
      CONCOURSE_BAGGAGECLAIM_DRIVER: ${CONCOURSE_BAGGAGECLAIM_DRIVER}
      CONCOURSE_BAGGAGECLAIM_LOG_LEVEL: ${CONCOURSE_BAGGAGECLAIM_LOG_LEVEL}
      CONCOURSE_GARDEN_LOG_LEVEL: ${CONCOURSE_GARDEN_LOG_LEVEL}

volumes:
  {{- if .Values.DB_VOLUME_NAME}}
  {{- else}}
  pgdata:
    driver: local
  {{- end }}

  {{- if .Values.WEB_KEYS_VOLUME_NAME}}
  {{- else}}
  concourse-keys-web:
    driver: local
  {{- end }}

  {{- if .Values.WORKER_KEYS_VOLUME_NAME}}
  {{- else}}
  concourse-keys-worker:
    driver: local
  {{- end }}

  {{- if .Values.VAULT_SERVER_DATA_VOLUME_NAME}}
  {{- else}}
  vault-server-data:
    driver: local
  {{- end }}

  {{- if .Values.VAULT_SERVER_CONFIG_VOLUME_NAME}}
  {{- else}}
  vault-server-config:
    driver: local
  {{- end }}

  {{- if .Values.VAULT_CLIENT_CONFIG_VOLUME_NAME}}
  {{- else}}
  vault-client-config:
    driver: local
  {{- end }}
