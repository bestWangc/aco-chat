# Aco Chat

Flutter client for the Aco project.

Android and iOS are the primary targets. Web is enabled for local UI preview.

## Run

```bash
flutter pub get
flutter run
```

The API base URL defaults to the production API. For a device on the same LAN
as the development machine (`192.168.31.230`), start the app with the local API
address explicitly:

```bash
flutter run \
  --dart-define=ACO_API_BASE_URL=http://192.168.31.230:8082/api/v1
```

The local API must be listening on the LAN interface. In `aco-chat-api`, run:

```bash
HTTP_ADDR=0.0.0.0:8082 go run ./cmd/server
```

Check connectivity from the development machine with
`curl http://192.168.31.230:8082/healthz` before launching the app.
