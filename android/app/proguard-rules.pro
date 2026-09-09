# flutter_openim_sdk dispatches manager calls through reflection. Keep the
# manager fields and methods from being renamed or removed by R8 in release.
-keep class io.openim.flutter_openim_sdk.** { *; }
