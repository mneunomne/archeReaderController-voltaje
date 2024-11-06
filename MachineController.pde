class MachineController {
  Serial port;    // Create object from Serial class
  String val;     // Data received from the serial port
  
  // in order to go back to the beggining
  int accumulated_x = 0;
  int accumulated_y = 0;
  
  String lastMovement;

  int timeStarted=0;
  
  int portIndex = 2;
  int readingSegmentInterval = 5000;

	int microdelay = MICRODELAY_DEFAULT;

  boolean noMachine = false;

  boolean waitNextMovement = false;

  MachineController(PApplet parent, boolean _noMachine) {
    // if no machine, don't connect to serial
    noMachine = _noMachine;
    if (noMachine) return;
    // Connect to Serial
    print("[MachineController] SerialList: ");
    printArray(Serial.list());
    String portName = Serial.list()[portIndex]; //change the 0 to a 1 or 2 etc. to match your port
    port = new Serial(parent, portName, 115200);    
  }

  void update () {
    if (waitNextMovement) {
      if (millis() - timeStarted > reading_rect_interval) {
        waitNextMovement = false;
        startMovement();
      }
    }
  }

  void startMovement() {
    int in_row_index = current_segment_index % segment_rows;
    //println("startMovement", macroStates[macroState], current_segment_index, in_row_index, current_row_index, segment_rows);
		if (current_col_index < segment_cols - 1) {
			// continue moving same direction
			macroState = READING_RECT;
			moveX(RECT_WIDTH);
			current_col_index+=1;
		} else { // if at the end of the row 
			if (current_row_index < segment_rows-1) { // of its it not the last row
				// jump row
				jumpRow();
			} else { // end reading plate
				current_segment_index=0;
				returnToTop();
			}
		}
  }

  void goToNextSegment() {
		macroState = READING_RECT;
    timeStarted = millis();
    waitNextMovement = true;
  }

  void setInitialPosition () {
    accumulated_x = 0;
    accumulated_y = 0;
  }

	void move(float x, float y) {
    if (noMachine) return;
    // move to a point
    sendMovement(x, y, 1, microdelay);
  }

  void moveX (float val) {
    //char dir = steps > 0 ? '+' : '-';
    //sendMovementCommand(dir, abs(steps), 'x');
		move(val, 0);
  }

  void moveY (float val) {
    //char dir = steps > 0 ? '+' : '-';
    //sendMovementCommand(dir, abs(steps), 'y');
		move(0, val);
  }

	void sendMovement(float _x, float _y, int type, int microdelay) {
    if (noMachine) return;
    // encode movement
    // String message = "[" + x + "," + y + "]";
		int x = int(_x * steps_per_pixel);
		int y = int(_y * steps_per_pixel); 
    String message = "G" + type +  " X" + x + " Y" + y + " F" + microdelay + " I" + 0 + '\n';
    port.write(message);
		lastMovement = message;
    println("[MachineController] Sent: " + message);
  }

  void returnToTop () {
    println("returnToTop!");
		sendSocketMessage("return_to_top");
    macroState = RETURNING_TOP;
    current_row_index=0;
		current_col_index=0;
    move(-RECT_WIDTH * (segment_cols-1), RECT_HEIGHT * (segment_rows-1));
  }

  void jumpRow () {
		current_segment_index+=1;
    current_row_index+=1;
		current_col_index = 0;
    macroState = JUMPING_ROW;
    accumulated_y+=RECT_HEIGHT;
    move(-RECT_WIDTH * (segment_cols-1), -RECT_HEIGHT);
  }

  void listenToSerialEvents () {
		if (noMachine) return;
    if ( port.available() > 0)  {  // If data is available,
      String inBuffer = port.readStringUntil('\n');
			if (inBuffer != null) {
				println("[MachineController] Received: ", inBuffer);
				if (inBuffer.contains("end")) {
					println("[MachineController] movement over: ", lastMovement);
					if (lastMovement != null) {
						onMovementEnd();
					}
				}
				if (inBuffer.contains("r")) {
					move(-114 - (RECT_WIDTH * (segment_cols-1)), 110 + (RECT_HEIGHT * (segment_rows-1)));
				}
			}
    }
	}

  void onMovementEnd () {
    // println("[MachineController] onMovementEnd", macroStates[macroState], current_segment_index, current_row_index, segment_rows);
    switch (macroState) {
      case STOP_MACHINE:
      case RUNNING_WASD_COMMAND:
        macroState = MACRO_IDLE;
        break;
			case JUMPING_ROW:
      case READING_RECT:
        current_segment_index+=1;
        readSegment(current_segment_index);
        break;
			case RETURNING_TOP:
				current_segment_index = 0;
				readSegment(0);
				break;
  	}
	}
}
