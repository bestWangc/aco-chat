# Aco Chat

Flutter client for the Aco project.

Android and iOS are the primary targets. Web is enabled for local UI preview.

## Run

```bash
flutter pub get
flutter run
```

The API base URL defaults to `http://localhost:8082/api/v1`. Platform-specific
configuration can be added in `lib/core/config/app_config.dart` as API features
are introduced.
