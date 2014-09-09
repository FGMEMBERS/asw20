################################################################################################
#
# calculate CG positions and convert units
#
################################################################################################

var weight_and_balance = func {

  # ------------------------  convert units  ------------------------
  
  var weight_empty_lbs = getprop("/fdm/jsbsim/inertia/empty-weight-lbs");
  var weight_empty_kg = weight_empty_lbs * 0.453592;
  setprop("/fdm/jsbsim/inertia/empty-weight-kg",weight_empty_kg);
 
  var weight_pilot_kg = getprop("/fdm/jsbsim/inertia/pointmass-weight-kg[0]");
  var weight_pilot_lbs = weight_pilot_kg * 2.204623;
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]",weight_pilot_lbs) ;

  var weight_baggage_kg = getprop("/fdm/jsbsim/inertia/pointmass-weight-kg[1]");
  var weight_baggage_lbs = weight_baggage_kg * 2.204623;
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]",weight_baggage_lbs) ;

  var weight_trimdisc_kg = getprop("/fdm/jsbsim/inertia/pointmass-weight-kg[2]");
  var weight_trimdisc_lbs = weight_trimdisc_kg * 2.204623;
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[2]",weight_trimdisc_lbs) ;

  var weight_trimweight_kg = getprop("/fdm/jsbsim/inertia/pointmass-weight-kg[3]");
  var weight_trimweight_lbs = weight_trimweight_kg * 2.204623;
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]",weight_trimweight_lbs) ;
  
  var weight_instruments_kg = getprop("/fdm/jsbsim/inertia/pointmass-weight-kg[4]");
  var weight_instruments_lbs = weight_instruments_kg * 2.204623;
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[4]",weight_instruments_lbs) ;
  
  var weight_kg = getprop("/fdm/jsbsim/inertia/waterballast_total_slider-kg");
  var weight_lbs = weight_kg * 2.204623;
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[5]",weight_lbs / 2.) ;
  setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[6]",weight_lbs / 2.) ;

  var weight_lbs = getprop("/fdm/jsbsim/inertia/weight-lbs");
  var weight_kg = weight_lbs * 0.453592;
  setprop("/fdm/jsbsim/inertia/weight-kg",weight_kg);

     # ------  calculate weight of non lift producing components  -----------
     #
     #  		 Ref. 4 p. 1: wing panel = 153pounds  
     var weight_non_lift_lbs =    weight_empty_lbs 
     				- ( 2. * 153. ) 
	    			+ weight_pilot_lbs
     				+ weight_baggage_lbs
	    			+ weight_trimdisc_lbs
	    			+ weight_trimweight_lbs
	    			+ weight_instruments_lbs
	    			;
     setprop("/fdm/jsbsim/inertia/weight_non_lift-lbs",weight_non_lift_lbs);			
     # ----------------------------------------------------------------------		
  var weight_non_lift_kg = weight_non_lift_lbs * 0.453592;
  setprop("/fdm/jsbsim/inertia/weight_non_lift-kg",weight_non_lift_kg);


  var area_sqft = getprop("/fdm/jsbsim/metrics/Sw-sqft");
  var area_sqm = area_sqft * 0.09290;
  setprop("/fdm/jsbsim/metrics/Sw-sqm",area_sqm);


  # ------------------------  calculate CG position  ------------------------
  #
  #  Important: Datum is the wing root leading edge!
  #
  #  the first part of this routine is not really necessary! 
  #  /fdm/jsbsim/inertia/cg-x-in has done the job already!
  #  1mm = 0.0393701inch
  #  1m  = 39.3701inch
  var x_empty       = 0.6283 * 39.3701; # getprop("/fdm/jsbsim/inertia/cg-x-in");  # 0.538 * 39.3701;
  var x_pilot       = getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[0]");
  var x_baggage     = getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[1]");
  var x_trimdisc    = getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[2]");
  var x_permanent   = getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[3]");
  var x_instruments = getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[4]");
  
  var m_empty       = getprop("/fdm/jsbsim/inertia/empty-weight-lbs");
  var m_pilot       = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]");
  var m_baggage     = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]");
  var m_trimdisc    = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[2]");
  var m_permanent   = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]");
  var m_instruments = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[4]");
  
  # x-pilot = f(m_pilot)   ref. 2 p. 30a
  m_pilot_kg = m_pilot * 0.453592 ;
  var x_pilot_mm = ( m_pilot_kg - 65. ) * ( -550. + 625. ) / ( 115. - 65. ) - 625.  ;
  var x_pilot    = x_pilot_mm * 0.0393701 ;

  var x_cg_inch = ( m_empty * x_empty + m_pilot * x_pilot + m_baggage * x_baggage + 
                    m_trimdisc * x_trimdisc + m_permanent * x_permanent + 
		    m_instruments * x_instruments ) / 
                  ( m_empty + m_pilot + m_baggage + m_trimdisc + m_permanent + m_instruments) ;
  var x_cg_mm = x_cg_inch / 0.0393701 ; 

  setprop("/fdm/jsbsim/inertia/cg_mass_and_balance-inch",x_cg_inch) ;	     
  setprop("/fdm/jsbsim/inertia/cg_mass_and_balance-mm",x_cg_mm) ;
  setprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[0]",x_pilot) ;


  # --- empty weight CG --- 
  var x_cg_empty_inch = ( m_empty * x_empty + 
                          m_trimdisc * x_trimdisc + m_permanent * x_permanent + 
		          m_instruments * x_instruments ) / 
                        ( m_empty + m_trimdisc + m_permanent + m_instruments) ;
  var x_cg_empty_mm = x_cg_empty_inch / 0.0393701 ; 

  setprop("/fdm/jsbsim/inertia/cg_mass_and_balance_empty-inch",x_cg_empty_inch) ;	     
  setprop("/fdm/jsbsim/inertia/cg_mass_and_balance_empty-mm",x_cg_empty_mm) ;
  

  # --- wing loading ---
  var wing_loading_lbft2 = weight_lbs / area_sqft ;
  var wing_loading_kgm2  = weight_kg  / area_sqm ;
  setprop("/fdm/jsbsim/inertia/wing_loading_lbsqft",wing_loading_lbft2) ;
  setprop("/fdm/jsbsim/inertia/wing_loading_kgsqm",wing_loading_kgm2) ;  

}









