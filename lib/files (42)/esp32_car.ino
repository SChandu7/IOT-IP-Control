/*
  ESP32 Wi-Fi car — matches the default "ESP32 car" profile in the app.
  Soft-AP mode, so the phone connects straight to the board at 192.168.4.1.

  Endpoints:
    GET /                     -> "ok"          (health check)
    GET /forw?v=0..255        -> drive forward
    GET /back?v=0..255        -> drive reverse
    GET /left  /right         -> pivot
    GET /steer?a=-90..90      -> servo steering angle
    GET /brake  /stop         -> stop
    GET /horn                 -> buzzer beep
    GET /light/on  /light/off -> headlights
    GET /telemetry            -> {"speed":120,"angle":-12,"armed":true}
*/

#include <WiFi.h>
#include <WebServer.h>
#include <ESP32Servo.h>

const char* AP_SSID = "ESP32-CAR";
const char* AP_PASS = "12345678";   // 8 chars minimum

// L298N / TB6612 pins
const int IN1 = 26, IN2 = 27, IN3 = 14, IN4 = 12;
const int ENA = 25, ENB = 33;
const int SERVO_PIN = 13, BUZZER = 15, LIGHT = 2;

WebServer server(80);
Servo steer;

int  curSpeed = 0;
int  curAngle = 0;
bool lightsOn = false;

void motors(int left, int right) {           // -255..255 each side
  digitalWrite(IN1, left  >= 0); digitalWrite(IN2, left  < 0);
  digitalWrite(IN3, right >= 0); digitalWrite(IN4, right < 0);
  analogWrite(ENA, abs(left));
  analogWrite(ENB, abs(right));
}

int argInt(const char* name, int fallback) {
  if (!server.hasArg(name)) return fallback;
  return server.arg(name).toInt();
}

void setup() {
  Serial.begin(115200);
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(ENA, OUTPUT); pinMode(ENB, OUTPUT);
  pinMode(BUZZER, OUTPUT); pinMode(LIGHT, OUTPUT);
  steer.attach(SERVO_PIN);

  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.println(WiFi.softAPIP());          // 192.168.4.1

  server.on("/", []() { server.send(200, "text/plain", "ok"); });

  server.on("/forw", []() {
    curSpeed = constrain(argInt("v", 200), 0, 255);
    motors(curSpeed, curSpeed);
    server.send(200, "text/plain", "forw");
  });

  server.on("/back", []() {
    curSpeed = constrain(argInt("v", 200), 0, 255);
    motors(-curSpeed, -curSpeed);
    server.send(200, "text/plain", "back");
  });

  server.on("/left",  []() { motors(-180, 180); server.send(200, "text/plain", "left"); });
  server.on("/right", []() { motors(180, -180); server.send(200, "text/plain", "right"); });

  server.on("/steer", []() {
    curAngle = constrain(argInt("a", 0), -90, 90);
    steer.write(90 + curAngle);
    server.send(200, "text/plain", "steer");
  });

  server.on("/speed", []() {
    curSpeed = constrain(argInt("v", 0), 0, 255);
    server.send(200, "text/plain", "speed");
  });

  server.on("/brake", []() { motors(0, 0); curSpeed = 0; server.send(200, "text/plain", "brake"); });
  server.on("/stop",  []() { motors(0, 0); curSpeed = 0; server.send(200, "text/plain", "stop"); });

  server.on("/horn", []() {
    tone(BUZZER, 2000, 150);
    server.send(200, "text/plain", "horn");
  });

  server.on("/light/on",  []() { lightsOn = true;  digitalWrite(LIGHT, HIGH); server.send(200, "text/plain", "on"); });
  server.on("/light/off", []() { lightsOn = false; digitalWrite(LIGHT, LOW);  server.send(200, "text/plain", "off"); });

  server.on("/telemetry", []() {
    String j = "{\"speed\":" + String(curSpeed) +
               ",\"angle\":" + String(curAngle) +
               ",\"lights\":" + String(lightsOn ? "true" : "false") +
               ",\"armed\":true}";
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(200, "application/json", j);
  });

  server.onNotFound([]() { server.send(404, "text/plain", "no route"); });
  server.begin();
}

// Safety: cut the motors if the phone stops talking for 600 ms.
unsigned long lastSeen = 0;

void loop() {
  server.handleClient();
  if (server.client()) lastSeen = millis();
  if (curSpeed != 0 && millis() - lastSeen > 600) {
    motors(0, 0);
    curSpeed = 0;
  }
}
