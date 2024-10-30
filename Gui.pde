public class Gui {
  
  ControlP5 cp5;

  int cp_width = 200;
  int cp_height = 10;

  int chart_h = 150;
  int chart_w = 200;
  
  int margin = MARGIN;
  int y = margin; 

  Gui (ControlP5 _cp5) {
    cp5 = _cp5;
  }

  void init () {
    cp5.setColorForeground(color(255, 150));
    cp5.setColorBackground(color(0, 150));
    sliders();
    buttons();
    if (debug) {
      showDebugElements();
    }
  }

  void sliders () {
    cp5.addSlider("reading_rect_interval_slider")
      .setPosition(margin,y)
      .setSize(cp_width, cp_height)
      .setValue(reading_rect_interval_default)
      .setRange(1, 20)
      ;
    y+=cp_height+margin;
  }

  void buttons () {
    // Group bangButtons = cp5.addGroup("bangButtons").setPosition(width-100-margin,margin).setWidth(100);
    int fx = width - 100 - margin;
    int fy = margin * 2 + cp_height; 
    int button_w = 30;
    int button_h = 15;
    
    cp5.addBang("read_rect")
      .setPosition(fx, fy)
      .setSize(button_w, button_h)
      ;
    fy+= button_h+margin+10;
    
    cp5.addBang("read_rect_inverse")
      .setPosition(fx, fy)
      .setSize(button_w, button_h)
      ;
    fy+= button_h+margin+10;

    cp5.addBang("read_plate")
      .setPosition(fx, fy)
      .setSize(button_w, button_h)
      ;
    fy+= button_h+margin+10; 
    
    cp5.addBang("stop_machine")
      .setPosition(fx, fy)
      .setSize(button_w, button_h)
      ;
    fy+= button_h+margin+10;

  }


  void display () {
    fill(255);
    if (debug) {
      int fy = (margin * 2) + cp_height;
      int fx = margin;
      text("frameRate: " + frameRate, fx,fy);
      fy+=margin+5;
      text("timeElapsed: " + millis()/1000, fx,fy);
      fy+=margin+5;
      text("macroState: " + macroStates[macroState], fx,fy);
      fy+=margin+5;
    }
  }

  void hideButtons () {
    cp5.getController("read_rect_inverse").hide();
    cp5.getController("read_rect").hide();
    cp5.getController("read_plate").hide();
    cp5.getController("stop_machine").hide();
  }

  void showDebugElements () {
    showButtons();
  }

  void hideDebugElements () {
    hideButtons();
  }
  
  void showButtons () {
    cp5.getController("read_rect_inverse").show();
    cp5.getController("read_rect").show();
    cp5.getController("read_plate").show();
    cp5.getController("stop_machine").show();
  }
}
