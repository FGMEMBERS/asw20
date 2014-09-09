#  side string animation

var sidestring = func {

   var airspeed = getprop("velocities/airspeed-kt");
   var severity = 0;	   
   if  (  airspeed < 54 ) 
   {
    severity = ( math.sin (  math.pi * airspeed/54 ) * rand() ) ;
   }
   var deflection = getprop("fdm/jsbsim/aero/alpha-deg") + severity ;
   
   # influence of gravity on side-string (only for low airspeed)      
   var airspeed_norm = airspeed / 10. ; 
   if( airspeed_norm < 1. ) {
     var nx = getprop("accelerations/pilot/x-accel-fps_sec");
     var nz = getprop("accelerations/pilot/z-accel-fps_sec");
     
     var gravity_direction_deg = math.atan2(nz,nx) * 180. / math.pi;
     
     var deflection =  (1 - airspeed_norm ) * gravity_direction_deg +
   			    airspeed_norm   * deflection ;
     }
   setprop("instrumentation/sidestring",deflection);

   settimer(sidestring,0);

}

# Start the side string ASAP
sidestring();
