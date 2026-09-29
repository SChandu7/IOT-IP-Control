# ESP Remote — dynamic HTTP controller

Landscape controller app for an ESP32 car (or any board that answers HTTP).
Every button's **name** and **endpoint** are set inside the app, so one build
controls any device.

## How the dynamic part works

- Settings → **Device address**: `http://192.168.4.1` (change any time).
- Edit HUD → tap a control → type a name (`Forward`) and an endpoint (`forw`)
  → **Apply**. That button now calls `http://192.168.4.1/forw`.
- Value controls use placeholders:

| Control | Endpoint example | Sends |
|---|---|---|
| Slider / Pedal | `speed?v={v}` | `{v}` = value in your min–max range |
| Joystick | `move?x={x}&y={y}` | both axes |
| Steering wheel | `steer?a={a}` | angle in degrees |
| Hold button | `forw` + release `stop` | press / release |
| Toggle | `light/on` + `light/off` | on / off |
| D-pad | `forw,back,left,right` | four paths, one widget |
| Gauge / Status light | `telemetry` + JSON field `speed` | polled read |

Layouts are saved per profile and survive restarts. Export/import as JSON.

## Run it

```bash
flutter create . --project-name esp_rc --platforms android,ios
# keep the lib/ folder from this bundle, then
flutter pub get
flutter run
```

## Android config (required — plain HTTP to a local IP)

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<application
    android:usesCleartextTraffic="true"
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

`android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">192.168.4.1</domain>
        <domain includeSubdomains="true">192.168.0.0</domain>
        <domain includeSubdomains="true">192.168.1.1</domain>
    </domain-config>
    <base-config cleartextTrafficPermitted="true"/>
</network-security-config>
```

Without this, Android 9+ blocks every request and the app just times out.

## Play Store checklist

1. `applicationId` → something unique, e.g. `in.chandus7.espremote`.
2. Bump `version:` in `pubspec.yaml` for every upload.
3. Signing: create `key.jks`, add `key.properties`, wire it in
   `android/app/build.gradle`.
4. `flutter build appbundle --release` → upload the `.aab`.
5. Data safety form: the app collects nothing, sends data only to a device on
   the user's own network. Say exactly that.
6. Screenshots must be landscape (phone + 7" tablet).
7. Short description idea: "Turn your phone into a controller for any ESP32 or
   HTTP device. Name your own buttons and endpoints."

## ESP32 side

`esp32/esp32_car.ino` is a soft-AP sketch exposing every endpoint used by the
default profile, including `/telemetry` for the gauge. It also cuts the motors
if the phone stops talking for 600 ms.
