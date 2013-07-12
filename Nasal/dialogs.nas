var weight_and_balance_dialog = gui.Dialog.new("sim/gui/dialogs/asw20/weight_and_balance/dialog", 
                                               "Aircraft/asw20/Dialogs/weight_and_balance.xml");
				   
var hook_dialog = gui.Dialog.new("sim/gui/dialogs/asw20/hook/dialog", 
                                 "Aircraft/asw20/Dialogs/hook.xml");
				   


# ####################################################################################
# ####################################################################################
# Nasal script for dialogs
#
# ####################################################################################
# Author: Klaus Kerner
# Version: 2012-07-09
#

# ####################################################################################
# basic fucntions to create dialogs
var config_dialog = gui.Dialog.new("sim/gui/dialogs/asw20/config/dialog", 
                                   "Aircraft/asw20/Dialogs/config.xml");

var aerotowing_ai_dialog = gui.Dialog.new(
                                  "sim/gui/dialogs/asw20/aerotowing_ai/dialog", 
                                  "Aircraft/asw20/Dialogs/aerotowing_ai.xml");

var aerotowing_advanced_dialog = gui.Dialog.new(
                                  "sim/gui/dialogs/asw20/aerotowing_advanced/dialog",
                                  "Aircraft/asw20/Dialogs/aerotowing_advanced.xml");


var dragrobot_dialog = gui.Dialog.new("sim/gui/dialogs/asw20/dragrobot/dialog", 
                                  "Aircraft/asw20/Dialogs/dragrobot.xml");
var dragrobot_advanced_dialog = gui.Dialog.new(
                                  "sim/gui/dialogs/asw20/dragrobot_advanced/dialog",
                                  "Aircraft/asw20/Dialogs/dragrobot_advanced.xml");

var winch_dialog = gui.Dialog.new("sim/gui/dialogs/asw20/winch/dialog", 
                                  "Aircraft/asw20/Dialogs/winch.xml");

var winch_advanced_dialog = gui.Dialog.new(
                                  "sim/gui/dialogs/asw20/winch_advanced/dialog", 
                                  "Aircraft/asw20/Dialogs/winch_advanced.xml");

 
# ####################################################################################
# winch dialog: helper function to cancel the winch, avoiding race conditions
var guiWinchCancel = func {
    asw20.removeWinch();
    asw20.resetWinch();
}
 


# ####################################################################################
# winch dialog: helper function to display winch operation points
var guiUpdateWinch = func {
    if ( getprop("sim/glider/winch/conf/pull_max_lbs") == nil ) {
        var pull_max_lbs = 900;
    }
    else {
        var pull_max_lbs = getprop("sim/glider/winch/conf/pull_max_lbs");
    }
    var pull_max_daN = pull_max_lbs * 0.45359237;
    setprop("sim/glider/gui/winch/pull_max_daN", pull_max_daN);
    
    if ( getprop("sim/glider/winch/conf/pull_max_speed_mps") == nil ) {
        var pull_max_speed_mps = 32;
    }
    else {
        var pull_max_speed_mps = getprop("sim/glider/winch/conf/pull_max_speed_mps");
    }
    var pull_max_speed_kmh = pull_max_speed_mps * 3.6;
    setprop("sim/glider/gui/winch/pull_max_speed_kmh", pull_max_speed_kmh);
    
  # for the speed correction, relative factors are used: 
    #  k_speed_x1 = speed_x1 / pull_max_speed_mps
    #  or: speed_x1 = k_speed_x1 * pull_max_speed_mps
    if ( getprop("sim/glider/winch/conf/k_speed_x1") == nil ) {
        var k_speed_x1 = 0.85;
    }
    else {
        var k_speed_x1 = getprop("sim/glider/winch/conf/k_speed_x1");
    }
    var speed_x1 = k_speed_x1 * pull_max_speed_mps * 3.6;
    setprop("sim/glider/gui/winch/speed_x1", speed_x1);
    
    #  k_speed_y2 = speed_y2 / pull_max_lbs
    #  or: speed_y2 = k_speed_y2 * pull_max_lbs
    if ( getprop("sim/glider/winch/conf/k_speed_y2") == nil ) {
        var k_speed_y2 = 0.00;
    }
    else {
        var k_speed_y2 = getprop("sim/glider/winch/conf/k_speed_y2");
    }
    var speed_y2 = k_speed_y2 * pull_max_lbs * 0.45359237;
    setprop("sim/glider/gui/winch/speed_y2", speed_y2);
    
  # for the angle correction, relative factors are used: 
    #  k_angle_x1 = angle_x1 / 70 (as 70° is hard-coded, not changeable)
    #  or: angle_x1 = k_angle_x1 * 70
    if ( getprop("sim/glider/winch/conf/k_angle_x1") == nil ) {
        var k_angle_x1 = 0.75;
    }
    else {
        var k_angle_x1 = getprop("sim/glider/winch/conf/k_angle_x1");
    }
    var angle_x1 = k_angle_x1 * 70;
    setprop("sim/glider/gui/winch/angle_x1", angle_x1);
    
    #  k_angle_y2 = angle_y2 / pull_max_lbs
    #  or: angle_y2 = k_angle_y2 * pull_max_lbs
    if ( getprop("sim/glider/winch/conf/k_angle_y2") == nil ) {
        var k_angle_y2 = 0.30;
    }
    else {
        var k_angle_y2 = getprop("sim/glider/winch/conf/k_angle_y2");
    }
    var angle_y2 = k_angle_y2 * pull_max_lbs * 0.45359237;
    setprop("sim/glider/gui/winch/angle_y2", angle_y2);
}

var guiwinchinit = setlistener("sim/sginals/fdm-initialized", 
                                     guiUpdateWinch,,0);
var guiwinchspeed_x   = setlistener("sim/glider/winch/conf/pull_max_speed_mps", 
                                     guiUpdateWinch,,0);
var guiwinchforce_x   = setlistener("sim/glider/winch/conf/pull_max_lbs", 
                                     guiUpdateWinch,,0);
var guikspeedx1       = setlistener("sim/glider/winch/conf/k_speed_x1", 
                                     guiUpdateWinch,,0);
var guikspeedy2       = setlistener("sim/glider/winch/conf/k_speed_y2", 
                                     guiUpdateWinch,,0);
var guikanglex1       = setlistener("sim/glider/winch/conf/k_angle_x1", 
                                     guiUpdateWinch,,0);
var guikangley2       = setlistener("sim/glider/winch/conf/k_angle_y2", 
                                     guiUpdateWinch,,0);


# ####################################################################################
# drag-robot dialog: helper function to display properties in better readable SI units
var guiUpdateDragRobot = func {
    # min. takeoff speed 
    if ( getprop("sim/glider/dragger/conf/glob_min_speed_takeoff_mps") == nil ) {
        var min_speed_takeoff = 20 * 3.6;
    }
    else {
        var min_speed_takeoff = getprop(
                          "sim/glider/dragger/conf/glob_min_speed_takeoff_mps") * 3.6;
    }
    setprop("sim/glider/gui/dragrobot/min_speed_takeoff", min_speed_takeoff);
    
    # max. speed 
    if ( getprop("sim/glider/dragger/conf/glob_max_speed_mps") == nil ) {
        var max_speed = 36 * 3.6;
    }
    else {
        var max_speed = getprop("sim/glider/dragger/conf/glob_max_speed_mps") * 3.6;
    }
    setprop("sim/glider/gui/dragrobot/max_speed", max_speed);
    
    # max. tauten speed 
    if ( getprop("sim/glider/dragger/conf/glob_max_speed_tauten_mps") == nil ) {
        var max_speed_tauten = 3 * 3.6;
    }
    else {
        var max_speed_tauten = getprop(
                           "sim/glider/dragger/conf/glob_max_speed_tauten_mps") * 3.6;
    }
    setprop("sim/glider/gui/dragrobot/max_speed_tauten", max_speed_tauten);
    
}


# ####################################################################################
# drag-robot dialog: helper function to run the roboter, avoiding race conditions
var guiRunDragRobot = func {
    asw20.findDragger();    
    asw20.hookDragger();    
    asw20.startDragRobot();
}


# ####################################################################################
# drag-robot dialog: helper function to cancel the roboter, avoiding race conditions
var guiCancelDragRobot = func {
    asw20.removeDragRobot();
    asw20.resetRobotAttributes();
    asw20.removeTowingRope();
}


var guidragrobotinit = setlistener("sim/signals/fdm-initialized", 
                                     guiUpdateDragRobot,,0);
var guidragrobot_1   = setlistener("sim/glider/dragger/conf/glob_min_speed_takeoff_mps", 
                                     guiUpdateDragRobot,,0);
var guidragrobot_2   = setlistener("sim/glider/dragger/conf/glob_max_speed_mps", 
                                     guiUpdateDragRobot,,0);
var guidragrobot_3   = setlistener("sim/glider/dragger/conf/glob_max_speed_tauten_mps", 
                                     guiUpdateDragRobot,,0);
















