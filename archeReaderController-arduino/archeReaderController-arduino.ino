#define STEP_PIN_X 2
#define DIR_PIN_X 5

#define STEP_PIN_Y 3
#define DIR_PIN_Y 6

#define ENA_PIN 8

#define microX1 1
#define microX2 3
#define microX3 4

#define microY1 1
#define microY2 3
#define microY3 4

#define limitX 9
#define limitY 10

#include <GCodeParser.h>

GCodeParser GCode = GCodeParser();

int minDelay = 2;
int maxDelayDefault = 200;


boolean reachedXLimit = false;
boolean reachedYLimit = false;

char c;

char buffer[14];

// current position

long curX = 0L;
long curY = 0L;

int steps_per_pixel = 68; 

void setup() {
  Serial.begin(115200);
  
  pinMode(STEP_PIN_X,OUTPUT);
  pinMode(DIR_PIN_X,OUTPUT);
  pinMode(STEP_PIN_Y,OUTPUT);
  pinMode(DIR_PIN_Y,OUTPUT);
  pinMode(ENA_PIN,OUTPUT);

  pinMode(limitX, INPUT_PULLUP);
  pinMode(limitY, INPUT_PULLUP);

  start();
  
}
void loop() {
  listenToPort();
  //checkLimitX();
  //checkLimitY();
}

bool checkLimitX(){
  int limitSwitchX = digitalRead(limitX);
  if (limitSwitchX == LOW) {
    if (!reachedXLimit) {
      Serial.println("end_limit_x");
      Serial.println(String(curX - 1000L));
      reachedXLimit = true;
      curX = 0L;
    }
    return true;
  } else {
    reachedXLimit = false;
    return false;
  }
}

bool checkLimitY() {
  int limitSwitchY = digitalRead(limitY);
  if (limitSwitchY == LOW) {
    if (!reachedYLimit) {
      Serial.println("end_limit_y");
      Serial.println(String(curY + 1000L));
      reachedYLimit = true;
      curY = 0L;
    }
    return true;
  } else {
    reachedYLimit = false;
    return false;
  }
}

void listenToPort() {
  while (Serial.available() > 0)
  {
    if (GCode.AddCharToLine(Serial.read()))
    {
      GCode.ParseLine();

      if (GCode.HasWord('G'))
      {
        // get value of X and Y 
        if (GCode.HasWord('X'))
        {
          long posX = GCode.GetWordValue('X');
          long posY = GCode.GetWordValue('Y');
          int microdelay = GCode.GetWordValue('F');
          int index = GCode.GetWordValue('I');
          // index to string end_{index}
          // buffer
          char buffer[14];
          int out = sprintf(buffer, "end_%d", index);
          move(posX, posY, microdelay);
          // repond to the sender the current position
          Serial.println(buffer);
        }
      }
    }
  }
}

void goHome () {
  moveX(100000L, 1, 200, false);
  moveY(100000L, -1, 200, false);
}


void start () {
  delay(100);

  digitalWrite(ENA_PIN,LOW); // enable motor HIGH -> DISABLE
  digitalWrite(ENA_PIN,LOW); // enable motor HIGH -> DISABLE
  // initial movement 
  moveX(500L, 1, 500, false);
  moveY(500L, -1, 500, false);
  moveX(500L, -1, 500, false);
  moveY(500L, 1, 500, false);

  goHome();

  Serial.println("r");
}

// Cubic interpolation function
float cubicInterpolate(float t) {
    return 3 * t * t - 2 * t * t * t;
}

// Custom cubic interpolation function for faster acceleration/deceleration
float customCubicInterpolate(float t) {
    // Custom cubic function to emphasize faster changes
    if (t < 0.5) {
        return 4 * t * t * t; // Faster acceleration
    } else {
        float p = (t - 1);
        return 1 + 4 * p * p * p; // Faster deceleration
    }
}

void move(long diffX, long diffY, int maxDelay) {
  // Serial.println("diff");
  // Serial.println(diffX);
  // Serial.println(diffY);
  Serial.print("diff: X ");
  Serial.print(diffX);
  Serial.print(" Y ");
  Serial.println(diffY);

  // if maxDelay is not set, use default
  if (maxDelay == 0) {
    maxDelay = maxDelayDefault;
  }

  // Determine the direction for each axis
  int dirX = (diffX > 0) ? 1 : -1;
  int dirY = (diffY > 0) ? 1 : -1;

  // Calculate the total steps for each axis
  long totalStepsX = labs(diffX * steps_per_pixel);
  long totalStepsY = labs(diffY * steps_per_pixel);

  Serial.print("totalStepsX: ");
  Serial.print(String(totalStepsX));
  Serial.print(" Y: ");
  Serial.println(String(totalStepsY));

  if (totalStepsX > 0 && totalStepsY == 0) {
    moveX(totalStepsX, dirX, maxDelay, false);
    return;
  }
  
  if (totalStepsX == 0 && totalStepsY > 0) {
    moveY(totalStepsY, dirY, maxDelay, false);
    return;
  }

  if (totalStepsX == 0 && totalStepsY == 0) {
    return;
  }


  // Determine the larger number of steps
  long maxSteps = max(totalStepsX, totalStepsY);

  // Calculate step size for each axis
  float stepSizeX = (float)totalStepsX / maxSteps;
  float stepSizeY = (float)totalStepsY / maxSteps;

  /* debug
  Serial.print("debug -");
  Serial.print("stepSizeX: ");
  Serial.print(stepSizeX);
  Serial.print("stepSizeY: ");
  Serial.print(stepSizeY);
  Serial.print("maxSteps: ");
  Serial.print(maxSteps);
  Serial.print("totalStepsX: ");
  Serial.print(totalStepsX);
  Serial.print("totalStepsY: ");
  Serial.print(totalStepsY);
  Serial.println(".");
  */

  // Variables to keep track of accumulated error
  float errorX = 0;
  float errorY = 0;

  float stepX = 0;
  float stepY = 0;
  
  int curDelay = maxDelay;
  int half = maxSteps / 2;
  int diffDelay = maxDelay - minDelay;
  // Move both axes simultaneously, adjusting step size if needed
  for (int i = 0; i < maxSteps; i++) {
    /*
    float ratio = (float)i / maxSteps;
    if (i < half) {
      float _ratio =  ratio * 2;
      float cubicRatio = customCubicInterpolate(_ratio);
      curDelay = maxDelay - (diffDelay * cubicRatio); 
    } else {
      float _ratio =  (ratio - 0.5) * 2;
      float cubicRatio = customCubicInterpolate(_ratio);
      curDelay = minDelay + (diffDelay * cubicRatio); 
    }
    // printf(" %d %.6f \n", curDelay, ratio);
    */

    if (checkLimitX() && checkLimitY()) {
      break;
    }

    stepX += stepSizeX;
    stepY += stepSizeY;

    if (stepX >= 1.0) {
      moveX(1L, dirX, curDelay, false);
      curX += 1*dirX;
      stepX -= 1.0;
    }

    if (stepY >= 1.0) {
      moveY(1L, dirY, curDelay, false);
      curY += 1*dirY;
      stepY -= 1.0;
    }
  }
}

void moveX (long steps, int dir, int microdelay, bool ignoreLimit) {
  if (dir > 0) {
      digitalWrite(DIR_PIN_X,LOW); // enable motor HIGH -> DISABLE
  } else {
      digitalWrite(DIR_PIN_X,HIGH); // enable motor HIGH -> DISABLE
  }
  for (int i = 0; i < steps; i++) {
    if (checkLimitX() && !ignoreLimit) {
      moveX(1000L, -dir, 500, true);
      return;
    }
    curX += 1 * dir;
    digitalWrite(STEP_PIN_X,HIGH);
    delayMicroseconds(1);
    digitalWrite(STEP_PIN_X,LOW);
    delayMicroseconds(microdelay);
  }
  
}

void moveY (long steps, int dir, int microdelay, bool ignoreLimit) {
  if (dir > 0) {
      digitalWrite(DIR_PIN_Y,LOW); // enable motor HIGH -> DISABLE
  } else {
      digitalWrite(DIR_PIN_Y,HIGH); // enable motor HIGH -> DISABLE
  }
  for (int i = 0; i < steps; i++) {
    if (checkLimitY() && !ignoreLimit) {
      moveY(1000L, -dir, 500, true);
      return;
    }
    curY += 1 * dir;
    digitalWrite(STEP_PIN_Y,HIGH);
    delayMicroseconds(1);
    digitalWrite(STEP_PIN_Y,LOW);
    delayMicroseconds(microdelay);
  }
}
