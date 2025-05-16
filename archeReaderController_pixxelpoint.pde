/**
 * Arche-Scripttures
 * Processing reading controller
 */

import java.util.*;
import controlP5.*;
import processing.serial.*;
import netP5.*;
import oscP5.*;
import processing.net.*; 

import websockets.*;

WebsocketServer ws;

boolean debug = true;

Gui gui;
MachineController machineController;

// Macro States
int one = 0;
static final int MACRO_IDLE                 = 0;
static final int READING_PLATE              = 1;
static final int RUNNING_WASD_COMMAND       = 2;
static final int READING_RECT               = 3;
static final int READING_RECT_INVERSE       = 4;
static final int JUMPING_ROW                = 5;
static final int STOP_MACHINE               = 6;
static final int SENDING_SEGMENT            = 7;
static final int WAITING_RESPONSE           = 8;
static final int WAITING_TIME               = 9;
static final int ERROR                      = 10;
static final int RETURNING_TOP_OFFSET       = 11;
static final int RETURNING_TOP              = 12;
static final int RESET_OFFSET               = 13;

static final int MICRODELAY_DEFAULT 				= 300;

int macroState = 0;
String [] macroStates = {
  "MACRO_IDLE",
  "READING_PLATE",
  "RUNNING_WASD_COMMAND",
  "READING_RECT",
  "READING_RECT_INVERSE",
  "JUMPING_ROW",
  "STOP_MACHINE",
  "SENDING_SEGMENT",
  "WAITING_RESPONSE",
  "WAITING_TIME",
  "ERROR",
  "RETURNING_TOP_OFFSET",
  "RETURNING_TOP",
  "RESET_OFFSET"
};

int reading_rect_interval_default = 5000;
int reading_rect_interval = reading_rect_interval_default;

PFont myFont;

int current_segment_index = 0;

int segment_rows = 9;
int segment_cols = 9;

float RECT_HEIGHT = 34.8; // 6000
float RECT_WIDTH  = 29; // 6000

int small_steps = 1;
int big_steps_w = int(RECT_WIDTH);
int big_steps_h = int(RECT_HEIGHT);

int current_row_index = 0;
int current_col_index = 0;

boolean noMachine = false;

static int MARGIN = 10;

int steps_per_pixel = 40;

void setup() {
  
  frameRate(30);

  size(400, 400); // much smaller

  // connect to socket
  //myClient = new Client(this, "127.0.0.1", 3000); 

  ws = new WebsocketServer(this,8025,"/arche-scriptures");

  smooth();
  
  loadConfig();

  machineController = new MachineController(this, noMachine);

  ControlP5 cp5 = new ControlP5(this);
  gui = new Gui(cp5);
  gui.init();

  myFont = createFont("PTMono-Regular", 9);
  textFont(myFont);

  // set initial debug state
  toggleDebug(false);
}

void loadConfig() {
  // load json file data/config.json
}

void draw() {
  background(0);
  // update gui chart with the value from the camera 
  gui.display();
  if (!noMachine) {
    machineController.listenToSerialEvents();
    machineController.update();
  }
}

/*
  ControlP5 listeners
*/
void small_steps_slider (float value) {
  small_steps = floor(value);
  println("small_steps_slider", value, small_steps);
}

void reading_rect_interval_slider (float value) {
  reading_rect_interval = int(value);
}

/*
  ControlP5 Bang Buttons
*/

void read_plate () {
  macroState = READING_PLATE;
  // machineController.runRect();
  machineController.setInitialPosition();
  readSegment(current_segment_index);
}

void stop_machine () {
  macroState = STOP_MACHINE;
}

void wasd_command (char key) {
  macroState = RUNNING_WASD_COMMAND;
  switch (key) {
    /* Movements */
    case 'w': machineController.moveY(small_steps); break;
    case 'a': machineController.moveX(small_steps); break;
    case 's': machineController.moveY(-small_steps); break;
    case 'd': machineController.moveX(-small_steps); break;
    /* big movements */
    case 'W': machineController.moveY(big_steps_h); break;
    case 'A': machineController.moveX(big_steps_w); break;
    case 'S': machineController.moveY(-big_steps_h); break;
    case 'D': machineController.moveX(-big_steps_w); break;
  }
}

void toggleDebug (boolean value) {
  debug = value;
  if (debug) {
    gui.showDebugElements();
  } else {
    gui.hideDebugElements();
  }
}

import http.requests.*;

void sendSocketMessage (String message) {
  println("sendSocketMessage", message);
	// broadcast message to all connected clients
	ws.sendMessage(message);
}

void readSegment (int segmentIndex) {
	// wait 1 second before sending the segment
	delay(2000);
	println("get avaraged frames");
  GetRequest get = new GetRequest("http://0.0.0.0:3000/get_avaraged_frames");
  get.send();
  println("Reponse Content: " + get.getContent());

  macroState = SENDING_SEGMENT;
  println("send Segment Http");
  get = new GetRequest("http://0.0.0.0:3000/on_segment/" + segmentIndex);
  get.send();
  macroState = WAITING_RESPONSE;
  println("Reponse Content: " + get.getContent());
  println("Reponse Content-Length Header: " + get.getHeader("Content-Length"));
	if (segmentIndex == 0) {
		macroState = READING_RECT;
	} else {
		macroState = WAITING_TIME;
	}
	if (get.getContent().equals("fail")) {
		// broadcast error to all clients
		sendSocketMessage("index-" + segmentIndex + "-fail");
		println("Error on segment: " + segmentIndex);
		reading_rect_interval = 0;
	} else {
		sendSocketMessage("index-" + segmentIndex + "-detection-" + get.getContent());
		reading_rect_interval = reading_rect_interval_default;
	}
	machineController.goToNextSegment();
}

void sendClearMessage () {
  println("sendClearMessage");
  GetRequest get = new GetRequest("http://0.0.0.0:3000/clear");
  get.send();
  System.out.println("Reponse Content: " + get.getContent());
  System.out.println("Reponse Content-Length Header: " + get.getHeader("Content-Length"));
}

void startReadingPlate () {
  macroState = READING_PLATE;
  machineController.setInitialPosition();
  current_segment_index = 0;
  readSegment(current_segment_index);
}

// wasd movement keys
void keyPressed() {
  switch (key) {
    /* Movements */
    case 'w': 
    case 'a': 
    case 's': 
    case 'd': 
    case 'W': 
    case 'A': 
    case 'S': 
    case 'D': wasd_command(key); break;
    case '.': toggleDebug(!debug); break;
    case 'r': startReadingPlate(); break;
    case 'c': sendClearMessage(); break;
    case '1': readSegment(0); break;
    case '2': readSegment(1); break;
    case '3': readSegment(2); break;
    case '4': readSegment(3); break;
    case '5': readSegment(4); break;
    case '6': readSegment(5); break;
    case '7': readSegment(6); break;
    case '8': readSegment(7); break;
    case '9': readSegment(8); break;
    case '0': readSegment(9); break;
  }
}
