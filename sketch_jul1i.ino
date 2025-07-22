#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecureBearSSL.h>
#include <time.h>

const char* WIFI_SSID = "GalaxyA04e2115";
const char* WIFI_PASS = "12345678";


const long GMT_OFFSET_SEC = 19800;
const int DST_OFFSET_SEC = 0;


#define DATA D2
#define CLOCK D3
#define LATCH D4


#define SEL0 D5
#define SEL1 D6
#define SEL2 D7
#define ANALOG_PIN A0

const int NUM_SLOTS = 6;
const int PRESSURE_THRESHOLD = 30;


uint8_t shiftRegState[3] = {0, 0, 0};


bool slotOccupied[NUM_SLOTS] = {false};
time_t slotEggTimestamp[NUM_SLOTS] = {0};


int lastPressureReading[NUM_SLOTS] = {0};


String commandBuffer = "";
bool commandReady = false;


unsigned long lastFsrReadTime = 0;
const unsigned long FSR_READ_PERIOD = 7000;  


const int ledBitMap[NUM_SLOTS][3] = {
  {0, 1, 2}, {3, 4, 5}, {6, 7, 8},
  {9,10,11}, {12,13,14}, {15,16,17}
};

const char* FIREBASE_PROJECT_ID = "smarteggtray";
const char* FIREBASE_API_KEY = "AIzaSyAlMr3HuJoWgMhrvJsuSRBux_us5X4pXBc";
const char* FIREBASE_HOST = "firestore.googleapis.com";


WiFiClientSecure client;
HTTPClient https;


void initializeHardware();
void connectToWiFi();
void syncTime();
time_t getCurrentTime();

void readAllSlots();
int readSlotPressure(int slotIndex);
void setSlotLedColor(int slotIndex, const String& color);
void updateShiftRegisterOutput();

void setLedBit(int bitPos);
void clearLedBit(int bitPos);

void processSerialCommands();
void parseCommand(const String& cmd);

void selectMultiplexerChannel(int channel);

void printTimestamp(time_t ts);

void serialEvent();

void updateFirestoreSlot(int slotIndex, bool occupied, time_t timestamp);


void setup() {
  Serial.begin(115200);

  client.setInsecure();  

  initializeHardware();
  connectToWiFi();
  syncTime();

  commandBuffer.reserve(200);
  updateShiftRegisterOutput();
}


void loop() {
  time_t now = getCurrentTime();
  unsigned long currentMillis = millis();

  if (currentMillis - lastFsrReadTime >= FSR_READ_PERIOD) {
    lastFsrReadTime = currentMillis;
    readAllSlots();
  }

  
  for (int i = 0; i < NUM_SLOTS; i++) {
    if (slotOccupied[i]) {
      int daysOld = (now - slotEggTimestamp[i]) / 86400;
      if (daysOld >= 14) setSlotLedColor(i, "red");
      else if (daysOld >= 7) setSlotLedColor(i, "yellow");
      else setSlotLedColor(i, "green");
    } else {
      setSlotLedColor(i, "off");
    }
  }

  
  if (commandReady) {
    parseCommand(commandBuffer);
    commandBuffer = "";
    commandReady = false;
  }

  delay(100);
}

// --- Functions ---

void initializeHardware() {
  pinMode(DATA, OUTPUT);
  pinMode(CLOCK, OUTPUT);
  pinMode(LATCH, OUTPUT);

  pinMode(SEL0, OUTPUT);
  pinMode(SEL1, OUTPUT);
  pinMode(SEL2, OUTPUT);
}

void connectToWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected.");
}

void syncTime() {
  configTime(GMT_OFFSET_SEC, DST_OFFSET_SEC, "pool.ntp.org", "time.nist.gov");
  Serial.print("Syncing time");
  while (time(nullptr) < 100000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nTime synced.");
}

time_t getCurrentTime() {
  return time(nullptr);
}

void readAllSlots() {
  time_t now = getCurrentTime();
  for (int i = 0; i < NUM_SLOTS; i++) {
    int pressureVal = readSlotPressure(i);
    lastPressureReading[i] = pressureVal;

    if (pressureVal > PRESSURE_THRESHOLD && !slotOccupied[i]) {
      slotOccupied[i] = true;
      slotEggTimestamp[i] = now;
      Serial.print("Egg placed in slot ");
      Serial.print(i + 1);
      Serial.print(" at ");
      printTimestamp(slotEggTimestamp[i]);
      Serial.println();

      updateFirestoreSlot(i, true, slotEggTimestamp[i]);
    }
    else if (pressureVal <= PRESSURE_THRESHOLD && slotOccupied[i]) {
      slotOccupied[i] = false;
      slotEggTimestamp[i] = 0;
      Serial.print("Egg removed from slot ");
      Serial.println(i + 1);

      updateFirestoreSlot(i, false, 0);
    }
  }
}

int readSlotPressure(int slotIndex) {
  selectMultiplexerChannel(slotIndex);
  delay(2);
  return analogRead(ANALOG_PIN);
}

void setSlotLedColor(int slotIndex, const String& color) {
  int rBit = ledBitMap[slotIndex][0];
  int gBit = ledBitMap[slotIndex][1];
  int bBit = ledBitMap[slotIndex][2];

  // Clear all bits first
  clearLedBit(rBit);
  clearLedBit(gBit);
  clearLedBit(bBit);

  if (color == "red") {
    setLedBit(rBit);
  } else if (color == "green") {
    setLedBit(gBit);
  } else if (color == "yellow") {
    setLedBit(rBit);
    setLedBit(gBit);
  }
  updateShiftRegisterOutput();
}

void setLedBit(int bitPos) {
  int byteIndex = bitPos / 8;
  int bitIndex = bitPos % 8;
  bitSet(shiftRegState[byteIndex], bitIndex);
}

void clearLedBit(int bitPos) {
  int byteIndex = bitPos / 8;
  int bitIndex = bitPos % 8;
  bitClear(shiftRegState[byteIndex], bitIndex);
}

void updateShiftRegisterOutput() {
  digitalWrite(LATCH, LOW);
  
  shiftOut(DATA, CLOCK, MSBFIRST, shiftRegState[2]);
  shiftOut(DATA, CLOCK, MSBFIRST, shiftRegState[1]);
  shiftOut(DATA, CLOCK, MSBFIRST, shiftRegState[0]);
  digitalWrite(LATCH, HIGH);
}

void selectMultiplexerChannel(int channel) {
  digitalWrite(SEL0, channel & 1);
  digitalWrite(SEL1, (channel >> 1) & 1);
  digitalWrite(SEL2, (channel >> 2) & 1);
}

void printTimestamp(time_t ts) {
  struct tm* timeInfo = localtime(&ts);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", timeInfo);
  Serial.print(buf);
}

void serialEvent() {
  while (Serial.available()) {
    char ch = (char)Serial.read();
    if (ch == '\n' || ch == '\r') {
      if (commandBuffer.length() > 0) commandReady = true;
    } else {
      commandBuffer += ch;
    }
  }
}

void parseCommand(const String& cmd) {
  String command = cmd;
  command.trim();

  int spacePos = command.indexOf(' ');
  if (spacePos == -1) return;

  int slotNum = command.substring(0, spacePos).toInt();
  int daysOld = command.substring(spacePos + 1).toInt();

  if (slotNum < 0 || slotNum >= NUM_SLOTS) {
    Serial.println("Invalid slot.");
    return;
  }

  if (daysOld == 0) {
    // Remove egg manually
    slotOccupied[slotNum] = false;
    slotEggTimestamp[slotNum] = 0;
    setSlotLedColor(slotNum, "off");
    Serial.print("Egg removed from slot ");
    Serial.println(slotNum);

    updateFirestoreSlot(slotNum, false, 0);
  } else if (daysOld >= 1 && daysOld <= 30) {
    if (!slotOccupied[slotNum]) {
      Serial.print("No egg placed in slot ");
      Serial.println(slotNum);
      return;
    }
    slotEggTimestamp[slotNum] = getCurrentTime() - (daysOld * 86400);
    Serial.print("Set egg in slot ");
    Serial.print(slotNum);
    Serial.print(" as ");
    Serial.print(daysOld);
    Serial.println(" days old.");

    updateFirestoreSlot(slotNum, true, slotEggTimestamp[slotNum]);
  }
}


void updateFirestoreSlot(int slotIndex, bool occupied, time_t timestamp) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Cannot update Firestore.");
    return;
  }

  String slotDoc = String("slot") + String(slotIndex + 1);

  
  String url = String("https://") + FIREBASE_HOST + "/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents/eggs/" + slotDoc + "?key=" + FIREBASE_API_KEY;

  
  String jsonPayload = "{ \"fields\": {";

  jsonPayload += "\"slot\": { \"stringValue\": \"" + slotDoc + "\" },";
  if (occupied) {
    jsonPayload += "\"date\": { \"stringValue\": \"";

    
    struct tm* timeInfo = localtime(&timestamp);
    char dateStr[11];  
    strftime(dateStr, sizeof(dateStr), "%Y-%m-%d", timeInfo);

    jsonPayload += String(dateStr) + "\" }";
  } else {
    jsonPayload += "\"date\": { \"stringValue\": \"\" }";
  }
  jsonPayload += "} }";

  Serial.print("Updating Firestore slot: ");
  Serial.println(slotDoc);
  Serial.print("Payload: ");
  Serial.println(jsonPayload);

  https.begin(client, url);
  https.addHeader("Content-Type", "application/json");

  int httpCode = https.PATCH(jsonPayload);  

  if (httpCode > 0) {
    String payload = https.getString();
    Serial.print("HTTP Response code: ");
    Serial.println(httpCode);
    Serial.println(payload);
  } else {
    Serial.print("Error on sending PATCH: ");
    Serial.println(httpCode);
  }
  https.end();
}
