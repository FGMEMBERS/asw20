##################################################################
#
# Wing Failure: Reset all failure values
#
################################################################## 

var wing_failure_repair = func { 
      setprop("orientation/roll-deg", 0. );  
      setprop("sim/asw20/wing-failure", 0 );
      setprop("sim/asw20/wing-failure-direction", 0 );
      setprop("sim/asw20/wing-failure-left", 0 );
      setprop("sim/asw20/wing-failure-right", 0 );      
      setprop("fdm/jsbsim/metrics/Sw-sqft", 113. );
      setprop("ai/submodels/submodel[0]/count", 1 );
      setprop("ai/submodels/submodel[1]/count", 1 );
      print("plane repaired");
    }



##################################################################
#
# Set hook coordinates according to hook_in_use
#
##################################################################

var set_hook_coordinates = func(mode) { 
  # mode = 1 := winch
  # mode = 2 := towing
  var hook_in_use = getprop("sim/asw20/hook/hook-in-use");
  if(mode == 1 and hook_in_use == 0) hook_in_use = 1;
  if(mode == 2 and hook_in_use == 0) hook_in_use = 2; 
  
  if(hook_in_use < 2) {  #C.G. hook (FDM-system)        
     var x = -0.5 ;
     var y =  0.;
     var z = -0.6;
  }
  else{                  #nose hook (FDM-system) 
     var x = -2.25;
     var y =  0.;
     var z = -0.32;
  }
  setprop("sim/asw20/hook/hook_x_m", x ); 
  setprop("sim/asw20/hook/hook_y_m", y );
  setprop("sim/asw20/hook/hook_z_m", z ); 

}



################################################################################################
#
# Set default weight values
#
################################################################################################

var weight_and_balance_defaults = func {

  setprop("/fdm/jsbsim/inertia/pointmass-weight-kg[0]", 85.);
  setprop("/fdm/jsbsim/inertia/pointmass-weight-kg[1]", 6.);
  setprop("/fdm/jsbsim/inertia/pointmass-weight-kg[2]", 2.);
  setprop("/fdm/jsbsim/inertia/pointmass-weight-kg[3]", 0.);
  setprop("/fdm/jsbsim/inertia/pointmass-weight-kg[4]", 2.);
  setprop("/fdm/jsbsim/inertia/waterballast_total_slider-kg", 0.);
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[5]", 0.);
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[6]", 0.);
  setprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[0]",-23.425) ;
  
}


################################################################################################
#
# Avoid possible wing failure at startup
#
################################################################################################

if ( getprop("sim/asw20/wing-failure-enable") ) {
  setprop("sim/asw20/wing-failure-enable",0);
  settimer( func { setprop("sim/asw20/wing-failure-enable", 1 ); }, 2 );
  }

