
# ####################################################################################
# ####################################################################################
# Nasal script to handle aerotowing, with AI-dragger
#
# ####################################################################################
# Author: Klaus Kerner
# Version: 2012-03-16
# Modifications by D-NXKT (January 2014)
#
# ####################################################################################
# Concepts:
# 1. search for allready existing dragger in the property tree
# 2. if an existing dragger is too far away or no dragger exists: create a new one
# 3. hook in to the dragger, that is close to the glider
# 4. lift up into the air
# 5. finish towing

# ## properties tree setup
# to handle the aerotowing functionality following setup of the properties tree
# has been used
# /sim/glider/towing                         base node
# /sim/glider/towing/glob                    node, keeping all global configuration
#                                             attributes (default values)
# /sim/glider/towing/conf                    node, keeping all current configuration
#                                             attributes (currently in use)
# /sim/glider/towing/list                    node, keeping all possible candidates for
#                                             aerotowing, mainly used by gui

# existing properties from ai branch, to handle the dragger (or the drag-robot)
# /ai/models/xyz[x]                                       the dragger that lifts me up
#  ./id                                                   the id of the ai-model
#  ./callsign                                             the callsign of the dragger
#  ./position/latitude-deg                                latitude of dragger
#  ./position/longitude-deg                               longitude of dragger
#  ./position/altitude-ft                                 height of dragger
#  ./orientation/true-heading-deg                         heading
#  ./orientation/pitch-deg                                pitch
#  ./orientation/roll-deg                                 roll
#  ./velocities/true-airspeed-kt                          speed
#
# ## existing properties to get glider orientation
# /orientation/heading-deg
# /orientation/pitch-deg
# /orientation/roll-deg

# ## existing proterties from jsbsim config file, that are used to handle 
#     the towing forces
# /fdm/jsbsim/fcs/dragger-cmd-norm                       created by jsbsim config file
#                                                          1: dragger engaged
#                                                          0: drager not engaged
# /fdm/jsbsim/external_reactions/dragx/magnitude         created by jsbsim config file
# /fdm/jsbsim/external_reactions/dragy/magnitude         created by jsbsim config file
# /fdm/jsbsim/external_reactions/dragz/magnitude         created by jsbsim config file

# ## new properties to handle the dragger
# /sim/glider/towing/conf/...                     property tree current configuration
# /sim/glider/towing/glob/...                     property tree generic configuration
# .../rope_length_m                                length of rope, 
#                                                    set by config file or default
# .../nominal_towforce_lbs                         nominal force at nominal distance
# .../breaking_towforce_N                          max. force of tow
# .../rope_x1                                      describes relative starting point
#                                                    for force
# .../rope_characteristics                         describes force/elongation ratio
#                                                    of rope

# /sim/glider/towing/dragid                       the ID of /ai/models/xyz[x]/id
# /sim/glider/towing/hooked                       flag to control engaged tow
#                                                   1: rope hooked in
#                                                   0: rope not hooked in
# /sim/glider/towing/list/candidate[x]            keeps possible draggers
# /sim/glider/towing/list/candidate[x]/type       keeps type of dragger
#                                                   MP=multiplayer, 
#                                                   AI=ai-plane, 
#                                                   DR=drag roboter
# /sim/glider/towing/list/candidate[x]/id         the id from /ai/models/xyz[x]/id
# /sim/glider/towing/list/candidate[x]/callsign   the according callsign
# /sim/glider/towing/list/candidate[x]/distance   the distance to the glider
# /sim/glider/towing/list/candidate[x]/selected   boolean for choosen candidate

# ## new properties to handle animated towing rope
# /ai/models/towrope/...
# .../id
# .../callsign
# .../valid
# .../position/latitude-deg
# .../position/longitude-deg
# .../position/altitude-ft
# .../orientation/true-heading-deg
# .../orientation/pitch-deg
# .../orientation/roll-deg
# /models/model[x]/...
# .../path
# .../longitude-deg-prop
# .../latitude-deg-prop
# .../elevation-ft-prop
# .../heading-deg-prop
# .../roll-deg-prop
# .../pitch-deg-prop
# /sim/glider/towrope/...
# .../data/id_AI
# .../data/id_model
# .../data/rope_distance_m
# .../data/xstretch_rel
# .../data/rope_heading_deg
# .../data/rope_pitch_deg
# .../data/rope_roll_deg
# .../flag/exist


# ####################################################################################
# global variables in this module
var towing_timeincrement = 0;                        # timer increment



# ####################################################################################
# set aerotowing parameters to global values, if not properly defined by plane 
#   setup-file
# store global values or plane-specific values to prepare for reset option
var globalsTowing = func {
  var glob_rope_length_m = 60;
  var glob_nominal_towforce_lbs = 500;
  var glob_breaking_towforce_N = 6000;  # D-NXKT: according to ASW20 Flight Manual
  var glob_rope_x1 = 0.7;
  var glob_rope_characteristics = 9000; # D-NXKT: according to YASim (e.g. bocian)
  
  # set rope length X2, if not defined from "plane"-set.xml 
  if ( getprop("sim/glider/towing/conf/rope_length_m") == nil ) {
    setprop("sim/glider/towing/conf/rope_initial_length_m", glob_rope_length_m);
    setprop("sim/glider/towing/glob/rope_initial_length_m", glob_rope_length_m);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/rope_length_m", 
            getprop("sim/glider/towing/conf/rope_length_m"));
  }
  
  # set nominal force for pulling F2, if not defined from "plane"-set.xml
  if ( getprop("sim/glider/towing/conf/nominal_towforce_lbs") == nil ) {
    setprop("sim/glider/towing/conf/nominal_towforce_lbs", glob_nominal_towforce_lbs);
    setprop("sim/glider/towing/glob/nominal_towforce_lbs", glob_nominal_towforce_lbs);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/nominal_towforce_lbs", 
            getprop("sim/glider/towing/conf/nominal_towforce_lbs"));
  }
  
  # set breaking force for pulling Fmax, if not defined from "plane"-set.xml
  if ( getprop("sim/glider/towing/conf/breaking_towforce_N") == nil ) {
    setprop("sim/glider/towing/conf/breaking_towforce_N", glob_breaking_towforce_N);
    setprop("sim/glider/towing/glob/breaking_towforce_N", glob_breaking_towforce_N);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/breaking_towforce_N", 
            getprop("sim/glider/towing/conf/breaking_towforce_N"));
  }
  
  # set relative rope length X1, if not defined from "plane"-set.xml 
  if ( getprop("sim/glider/towing/conf/rope_x1") == nil ) {
    setprop("sim/glider/towing/conf/rope_x1", glob_rope_x1);
    setprop("sim/glider/towing/glob/rope_x1", glob_rope_x1);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/rope_x1", 
            getprop("sim/glider/towing/conf/rope_x1"));
  }
  
  # set relative rope characteristics, if not defined from "plane"-set.xml 
  if ( getprop("sim/glider/towing/conf/rope_characteristics") == nil ) {
    setprop("sim/glider/towing/conf/rope_characteristics", glob_rope_characteristics);
    setprop("sim/glider/towing/glob/rope_characteristics", glob_rope_characteristics);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/rope_characteristics", 
            getprop("sim/glider/towing/conf/rope_characteristics"));
  }
  
} # End Function globalsTowing



# ####################################################################################
# reset aerotowing parameters to global values
var resetTowing = func {
  # set rope length to global
  setprop("sim/glider/towing/conf/rope_length_m", 
            getprop("sim/glider/towing/glob/rope_length_m"));
  
  # set nominal force for pulling to global
  setprop("sim/glider/towing/conf/nominal_towforce_lbs", 
            getprop("sim/glider/towing/glob/nominal_towforce_lbs"));
  
  # set breaking force for pulling to global
  setprop("sim/glider/towing/conf/breaking_towforce_N", 
            getprop("sim/glider/towing/glob/breaking_towforce_N"));
  
  # set rope length X1 to global
  setprop("sim/glider/towing/conf/rope_x1", 
            getprop("sim/glider/towing/glob/rope_x1"));
  
  
  # set rope characteristics to global
  setprop("sim/glider/towing/conf/rope_characteristics", 
            getprop("sim/glider/towing/glob/rope_characteristics"));
  
} # End Function resetTowing



# ####################################################################################
# restore position to location before towing dialog
# used by gui, when aborting selection of dragger
var restorePosition = func {
  # reset to temporarily stored initial position (before calling gui)
  setprop("position/latitude-deg", getprop("sim/glider/towing/list/init_lat_deg"));
  setprop("position/longitude-deg", getprop("sim/glider/towing/list/init_lon_deg"));
  setprop("position/altitude-ft", getprop("sim/glider/towing/list/init_alt_ft"));
  setprop("orientation/heading-deg", getprop("sim/glider/towing/list/init_head_deg"));
  setprop("orientation/pitch-deg", 0);
  setprop("orientation/roll-deg", 0);
} # End Function restorePosition



# ####################################################################################
# listCandidates
# used by gui, for setting up an selection list of possible candidates
var listCandidates = func {
  
  # first check for available multiplayer and ai-planes 
  # if ai-objects are available 
  #   store them in an array
  #   get the glider position
  #   for every ai-object
  #     calculate the distance to the glider
  #     if the distance is lower than max. tow length
  #       get id
  #       get callsign
  #       print details to the console
  
  # local variables
  var aiobjects = [];                            # keeps the ai-objects from the 
                                                 #   property tree
  var candidates_id = [];                        # keeps all found candidates
  var candidates_dst_m = [];                     # keeps the distance to the glider
  var candidates_callsign = [];                  # keeps the callsigns
  var candidates_type = [];                      # keeps the type of candidate
  var dragid = 0;                                # id of dragger
  var callsign = 0;                              # callsign of dragger
  var cur = geo.Coord.new();                     # current processed ai-object
                                                 # from the current aiobject
  var lat_deg = 0;                               #   latitude
  var lon_deg = 0;                               #   longitude
  var alt_m = 0;                                 #   altitude
  var glider = geo.Coord.new();                  # coordinates of glider
  var distance_m = 0;                            # distance to ai-plane
  var counter = 0;                               # temporary counter
  var listbasis = "/sim/glider/towing/list/";    # string keeping basis of drag 
                                                 #   candidates list
  
  
  glider = geo.aircraft_position(); 
  
  # first scan for multiplayers
  aiobjects = props.globals.getNode("ai/models").getChildren("multiplayer"); 
  
  ###print("found MP: ", size(aiobjects));
  
  if (size(aiobjects) > 0 ) {
    foreach (var aimember; aiobjects) { 
      lat_deg = aimember.getNode("position/latitude-deg").getValue(); 
      lon_deg = aimember.getNode("position/longitude-deg").getValue(); 
      alt_m = aimember.getNode("position/altitude-ft").getValue() * FT2M; 
      cur = geo.Coord.set_latlon( lat_deg, lon_deg, alt_m );
      distance_m = (glider.distance_to(cur)); 
      
      append( candidates_id, aimember.getNode("id").getValue() );
      append( candidates_callsign, aimember.getNode("callsign").getValue() );
      append( candidates_dst_m, distance_m );
      append( candidates_type, "MP" );
    }
  }
  
  # second scan for ai-planes
  aiobjects = props.globals.getNode("ai/models").getChildren("aircraft"); 
  
  ###print("found AI: ", size(aiobjects));
  
  if (size(aiobjects) > 0 ) {
    foreach (var aimember; aiobjects) { 
      lat_deg = aimember.getNode("position/latitude-deg").getValue(); 
      lon_deg = aimember.getNode("position/longitude-deg").getValue(); 
      alt_m = aimember.getNode("position/altitude-ft").getValue() * FT2M; 
      cur = geo.Coord.set_latlon( lat_deg, lon_deg, alt_m );
      distance_m = (glider.distance_to(cur)); 
      
      append( candidates_id, aimember.getNode("id").getValue() );
      append( candidates_callsign, aimember.getNode("callsign").getValue() );
      append( candidates_dst_m, distance_m );
      append( candidates_type, "AI" );
    }
  }
  
  
  # some kind of sorting, criteria is distance, 
  # but only if there are more than 1 candidate
  if (size(candidates_id) > 1) {
    # first push the closest candidate on the first position
    for (var index = 1; index < size(candidates_id); index += 1 ) {
      if ( candidates_dst_m[0] > candidates_dst_m[index] ) {
        var tmp_id = candidates_id[index];
        var tmp_cs = candidates_callsign[index];
        var tmp_dm = candidates_dst_m[index];
        var tmp_tp = candidates_type[index];
        candidates_id[index] = candidates_id[0];
        candidates_callsign[index] = candidates_callsign[0];
        candidates_dst_m[index] = candidates_dst_m[0];
        candidates_type[index] = candidates_type[0];
        candidates_id[0] = tmp_id;
        candidates_callsign[0] = tmp_cs;
        candidates_dst_m[0] = tmp_dm;
        candidates_type[0] = tmp_tp;
      }
    }
    # then sort all the remaining candidates, if there are more than 2
    if (size(candidates_id) > 2) {
      # do all other sorting
      for (var index = 2; index < size(candidates_id); index += 1) {
        # compare and change
        var bubble = index;
        while (( candidates_dst_m[bubble] < candidates_dst_m[bubble - 1] ) and (bubble >1)) {
          # exchange elements
          var tmp_id = candidates_id[bubble];
          var tmp_cs = candidates_callsign[bubble];
          var tmp_dm = candidates_dst_m[bubble];
          var tmp_tp = candidates_type[bubble];
          candidates_id[bubble] = candidates_id[bubble - 1];
          candidates_callsign[bubble] = candidates_callsign[bubble - 1];
          candidates_dst_m[bubble] = candidates_dst_m[bubble - 1];
          candidates_type[bubble] = candidates_type[bubble - 1];
          candidates_id[bubble - 1] = tmp_id;
          candidates_callsign[bubble - 1] = tmp_cs;
          candidates_dst_m[bubble - 1] = tmp_dm;
          candidates_type[bubble - 1] = tmp_tp;
          bubble = bubble - 1;
        }
      }
    }
  }
  
  # now, finally write the five closest candidates to the property tree
  # if there are less than five, fill up with empty objects
  for (var index = 0; index < 5; index += 1 ) {
    if (index >= size(candidates_id)) {
      var candidate_x_id_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/id";
      var candidate_x_cs_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/callsign";
      var candidate_x_dm_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/distance_m";
      var candidate_x_tp_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/type";
      var candidate_x_sl_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/selected";
      setprop(candidate_x_id_prop, -1);
      setprop(candidate_x_cs_prop, "undef");
      setprop(candidate_x_dm_prop, 99999);
      setprop(candidate_x_tp_prop, "XX");
      setprop(candidate_x_sl_prop, 0);
      # set color in dialog for aerotowing
      var guigroup = index + 1;
      var guicolor = "sim/gui/dialogs/asw20/dragger/dialog/group[1]/group[" ~ guigroup ~ "]/text[";
        setprop(guicolor ~ "0]/color/green", 0.1 );
        setprop(guicolor ~ "0]/color/red", 0.1 );
        setprop(guicolor ~ "0]/color/blue", 0.1 );
        setprop(guicolor ~ "1]/color/green", 0.1 );
        setprop(guicolor ~ "1]/color/red", 0.1 );
        setprop(guicolor ~ "1]/color/blue", 0.1 );
        setprop(guicolor ~ "2]/color/green", 0.1 );
        setprop(guicolor ~ "2]/color/red", 0.1 );
        setprop(guicolor ~ "2]/color/blue", 0.1 );
        setprop(guicolor ~ "3]/color/green", 0.1 );
        setprop(guicolor ~ "3]/color/red", 0.1 );
        setprop(guicolor ~ "3]/color/blue", 0.1 );
    }
    else {
      var candidate_x_id_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/id";
      var candidate_x_cs_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/callsign";
      var candidate_x_dm_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/distance_m";
      var candidate_x_tp_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/type";
      var candidate_x_sl_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/selected";
      setprop(candidate_x_id_prop, candidates_id[index]);
      setprop(candidate_x_cs_prop, candidates_callsign[index]);
      setprop(candidate_x_dm_prop, candidates_dst_m[index]);
      setprop(candidate_x_tp_prop, candidates_type[index]);
      setprop(candidate_x_sl_prop, 0);
      # set color in dialog for aerotowing
      var guigroup = index + 1;
      var guicolor = "sim/gui/dialogs/asw20/dragger/dialog/group[1]/group[" ~ guigroup ~ "]/text[";
      if ( candidates_dst_m[index] < 1000) {
        setprop(guicolor ~ "0]/color/green", 0.9 );
        setprop(guicolor ~ "0]/color/red", 0.1 );
        setprop(guicolor ~ "0]/color/blue", 0.1 );
        setprop(guicolor ~ "1]/color/green", 0.9 );
        setprop(guicolor ~ "1]/color/red", 0.1 );
        setprop(guicolor ~ "1]/color/blue", 0.1 );
        setprop(guicolor ~ "2]/color/green", 0.9 );
        setprop(guicolor ~ "2]/color/red", 0.1 );
        setprop(guicolor ~ "2]/color/blue", 0.1 );
        setprop(guicolor ~ "3]/color/green", 0.9 );
        setprop(guicolor ~ "3]/color/red", 0.1 );
        setprop(guicolor ~ "3]/color/blue", 0.1 );
      }
      elsif ( candidates_dst_m[index] < 3000.01 ) {
        setprop(guicolor ~ "0]/color/green", 0.9 );
        setprop(guicolor ~ "0]/color/red", 0.1 );
        setprop(guicolor ~ "0]/color/blue", 0.9 );
        setprop(guicolor ~ "1]/color/green", 0.9 );
        setprop(guicolor ~ "1]/color/red", 0.1 );
        setprop(guicolor ~ "1]/color/blue", 0.9 );
        setprop(guicolor ~ "2]/color/green", 0.9 );
        setprop(guicolor ~ "2]/color/red", 0.1 );
        setprop(guicolor ~ "2]/color/blue", 0.9 );
        setprop(guicolor ~ "3]/color/green", 0.9 );
        setprop(guicolor ~ "3]/color/red", 0.1 );
        setprop(guicolor ~ "3]/color/blue", 0.9 );
      }
      else {
        setprop(guicolor ~ "0]/color/green", 0.1 );
        setprop(guicolor ~ "0]/color/red", 0.9 );
        setprop(guicolor ~ "0]/color/blue", 0.1 );
        setprop(guicolor ~ "1]/color/green", 0.1 );
        setprop(guicolor ~ "1]/color/red", 0.9 );
        setprop(guicolor ~ "1]/color/blue", 0.1 );
        setprop(guicolor ~ "2]/color/green", 0.1 );
        setprop(guicolor ~ "2]/color/red", 0.9 );
        setprop(guicolor ~ "2]/color/blue", 0.1 );
        setprop(guicolor ~ "3]/color/green", 0.1 );
        setprop(guicolor ~ "3]/color/red", 0.9 );
        setprop(guicolor ~ "3]/color/blue", 0.1 );
      }
    }
  }
  # and write the initial position of the glider to the property tree for 
  # cancel possibility
  setprop("sim/glider/towing/list/init_lat_deg", 
           getprop("position/latitude-deg"));
  setprop("sim/glider/towing/list/init_lon_deg", 
           getprop("position/longitude-deg"));
  setprop("sim/glider/towing/list/init_alt_ft", 
           getprop("position/altitude-ft"));
  setprop("sim/glider/towing/list/init_head_deg", 
           getprop("orientation/heading-deg"));
  
} # End Function listCandidates



# ####################################################################################
# selectCandidates
# used by gui, for selection of dragger and putting the glider behind dragger
var selectCandidates = func (select) {
  var candidates = [];
  var aiobjects = [];
  var initpos_geo = geo.Coord.new();
  var dragpos_geo = geo.Coord.new();
  # place behind dragger with a distance, that the tow is nearly tautened
  var rope_length_m = getprop("/sim/glider/towing/conf/rope_length_m");
  var tauten_relative = getprop("/sim/glider/towing/conf/rope_x1");
  var install_distance_m = rope_length_m * (tauten_relative - 0.02);
  
  # first reset all candidate selections and then set selected
  candidates = props.globals.getNode("sim/glider/towing/list").getChildren("candidate");
  foreach (var camember; candidates) { 
    camember.getNode("selected").setValue(0); 
  }
  var candidate_x_sl_prop = "sim/glider/towing/list/candidate[" ~ select ~ "]/selected";
  var candidate_x_id_prop = "sim/glider/towing/list/candidate[" ~ select ~ "]/id";
  var candidate_x_tp_prop = "sim/glider/towing/list/candidate[" ~ select ~ "]/type";
  setprop(candidate_x_sl_prop, 1);
  
  # next set properties for dragid
  setprop("sim/glider/towing/dragid", getprop(candidate_x_id_prop));
  # D-NXKT: somewhere needed properties 
  setprop("sim/hitches/aerotow/tow/dist",install_distance_m);
  setprop("sim/hitches/dragger/mp_last_reported_dist",install_distance_m);
  setprop("sim/hitches/dragger/local-pos-x", -5. ); # default values for dragger hook (needed for AI-draggers) 
  setprop("sim/hitches/dragger/local-pos-y", 0. );   
  setprop("sim/hitches/dragger/local-pos-z", 0. );
	  
  # and finally place the glider a few meters behind chosen dragger
  aiobjects = props.globals.getNode("ai/models").getChildren(); 
  foreach (var aimember; aiobjects) { 
    if ( (var c = aimember.getNode("id") ) != nil ) { 
      var testprop = c.getValue();
      if ( testprop == getprop(candidate_x_id_prop)) {
        # get and set callsign
	setprop("sim/glider/towing/dragcallsign", aimember.getNode("callsign").getValue() );
        # get coordinates
        drlat = aimember.getNode("position/latitude-deg").getValue(); 
        drlon = aimember.getNode("position/longitude-deg").getValue(); 
        dralt = (aimember.getNode("position/altitude-ft").getValue()) * FT2M; 
        drhed = aimember.getNode("orientation/true-heading-deg").getValue();
        # D-NXKT: set multiplayer hook to "open". This avoids an endless loop in function hookDragger which could occur in some cases
	if ( (var d = aimember.getNode("sim/hitches/aerotow/open") ) != nil ) {
	  aimember.getNode("sim/hitches/aerotow/open", 1).setBoolValue(0); 
	} 
	# D-NXKT: somewhere needed properties
        if ( (var c = aimember.getNode("sim/hitches/aerotow/local-pos-x") ) != nil ) {  #  set default dragger hook coordinates
	  aimember.getNode("sim/hitches/aerotow/local-pos-x").setValue(-5.);
	  aimember.getNode("sim/hitches/aerotow/local-pos-y").setValue(0.);
	  aimember.getNode("sim/hitches/aerotow/local-pos-z").setValue(0.);
	  aimember.getNode("sim/hitches/aerotow/tow/dist").setValue(-1.);
        }
      }
    }
  }
  dragpos_geo.set_latlon(drlat, drlon, dralt);
  initpos_geo.set_latlon(drlat, drlon, dralt);
  if (drhed > 180) {
    initpos_geo.apply_course_distance( (drhed - 180), install_distance_m );
  }
  else {
    initpos_geo.apply_course_distance( (drhed + 180), install_distance_m );
  }
  var initelevation_m = geo.elevation( initpos_geo.lat(), initpos_geo.lon() ) + 0.5;
  setprop("position/latitude-deg", initpos_geo.lat());
  setprop("position/longitude-deg", initpos_geo.lon());
  setprop("position/altitude-ft", initelevation_m * M2FT);
  setprop("orientation/heading-deg", drhed);
  setprop("orientation/roll-deg", 0);
  
} # End Function selectCandidates



# ####################################################################################
# clearredoutCandidates
# used by gui to clear red-out
# sometimes it happens, that the glider drops off a dragger, if a huge dragger has
# been selected. in that case you can get a red-out. and this function allows to 
# clear this.
var clearredoutCandidates = func {
  # remove redout blackout caused by selectCandidates()
  setprop("sim/rendering/redout/enabled", "false");
  setprop("sim/rendering/redout/alpha",0);
  
} # End Function clearredoutCandidates



# ####################################################################################
# removeCandidates
# used by gui to remove list of candidates, after selecting or aborting
var removeCandidates = func {
  # and finally remove the list of candidates
  props.globals.getNode("sim/glider/towing/list").remove();
  
} # End Function removeCandidates



# ####################################################################################
# findDragger
# used by key 
# used by gui, when dealing with drag roboter
# the first found plane, that is close enough and has callsign "dragger" will be used
var findDragger = func {
  
  # local variables
  var aiobjects = [];                     # keeps the ai-planes from the property tree
  var dragid = 0;                         # id of dragger
  var callsign = 0;                       # callsign of dragger
  var cur = geo.Coord.new();              # current processed ai-plane
  var lat_deg = 0;                        # latitude of current processed aiobject
  var lon_deg = 0;                        # longitude of current processed aiobject
  var alt_m = 0;                          # altitude of current processed aiobject
  var glider = geo.Coord.new();           # coordinates of glider
  var distance_m = 0;                     # distance to ai-plane
  
  setprop("sim/hitches/dragger/local-pos-x", -5. ); # default values for dragger hook (needed for AI-draggers) 
  setprop("sim/hitches/dragger/local-pos-y", 0. );   
  setprop("sim/hitches/dragger/local-pos-z", 0. );
  
  var towlength_m = getprop("sim/glider/towing/conf/rope_length_m");
  var distance_m_min = towlength_m;
 
  
  aiobjects = props.globals.getNode("ai/models").getChildren(); 
  glider = geo.aircraft_position(); 
  
  foreach (var aimember; aiobjects) { 
    if ( (var c = aimember.getNode("callsign") ) != nil ) { 
      callsign = c.getValue();
      dragid = aimember.getNode("id").getValue();
      # if ( callsign == "dragger" ) {      # D-NXKT: not limited to callsign dragger / takes nearest dragger instead
      #print('dragid= ',dragid);
      if ( dragid > 0 ) {
        lat_deg = aimember.getNode("position/latitude-deg").getValue(); 
        lon_deg = aimember.getNode("position/longitude-deg").getValue(); 
        alt_m = aimember.getNode("position/altitude-ft").getValue() * FT2M; 
        
        cur = geo.Coord.set_latlon( lat_deg, lon_deg, alt_m ); 
        distance_m = (glider.distance_to(cur)); 
        
        if ( distance_m < distance_m_min ) {  # D-NXKT: search nearest dragger
	  distance_m_min = distance_m;
          #atc_msg("dragger with id %s nearby in %s m", dragid, distance_m);
	  atc_msg("dragger with id %s nearby in %6.3f m", dragid, distance_m);
          setprop("sim/glider/towing/dragid", dragid);
	  setprop("sim/glider/towing/dragcallsign", callsign); 
	  setprop("sim/hitches/aerotow/tow/dist",distance_m);
	  setprop("sim/hitches/dragger/mp_last_reported_dist",distance_m);
	  if ( (var d = aimember.getNode("sim/hitches/aerotow/open") ) != nil ) {  #  set multiplayer hook to "open". Avoids an endless loop in function hookDragger which could occur in some cases
	    aimember.getNode("sim/hitches/aerotow/open", 1).setBoolValue(0); 
	  }
	  if ( (var c = aimember.getNode("sim/hitches/aerotow/local-pos-x") ) != nil ) {  #  get dragger hook coordinates
            #var draggerHookX = aimember.getNode("sim/hitches/aerotow/local-pos-x").getValue();
            #var draggerHookY = aimember.getNode("sim/hitches/aerotow/local-pos-y").getValue();
            #var draggerHookZ = aimember.getNode("sim/hitches/aerotow/local-pos-z").getValue();
	    #setprop("sim/hitches/dragger/local-pos-x",draggerHookX);
	    #setprop("sim/hitches/dragger/local-pos-y",draggerHookY);
	    #setprop("sim/hitches/dragger/local-pos-z",draggerHookZ);
	    # non-interactive MP draggers have this node but variable-values are not defined.
	    # This will cause an nasal error! Hence set some dummy values. In case of an "interactive"-MP plane 
	    # the correct values will be transmitted in the following loop
            aimember.getNode("sim/hitches/aerotow/local-pos-x").setValue(-5.);
            aimember.getNode("sim/hitches/aerotow/local-pos-y").setValue(0.);
            aimember.getNode("sim/hitches/aerotow/local-pos-z").setValue(0.);
	    aimember.getNode("sim/hitches/aerotow/tow/dist").setValue(-1.);
	  }
          #break; 
        }
        else {
          #atc_msg("dragger with id %s too far at %s m", dragid, distance_m);
	  atc_msg("dragger with id %s too far at %6.3f m", dragid, distance_m);
	}
    }
    }
  #  else {
  #    atc_msg("no dragger found");
  #  }
  }  
  
} # End Function findDragger



# ####################################################################################
# get the next free id of models/model members
# required for animation of towing rope
# should be shifted to a generic module as same function exists in dragrobot.nas
var getFreeModelID = func {
  
  #local variables
  var modelid = 0;                                 # for the next unsused id
  var modelobjects = {};                           # vector to keep all model objects
  
  modelobjects = props.globals.getNode("models", 1).getChildren(); # get model objects
  foreach ( var member; modelobjects ) { 
    # get data from member
    if ( (var c = member.getNode("id")) != nil) {
      var id = c.getValue();
      if ( modelid <= id ) {
        modelid = id +1;
      } 
    }
  }
  return(modelid);
}



# ####################################################################################
# create the towing rope in the model property tree
var createTowingRope = func {
  setprop("/sim/glider/dragger/flags/run", 1); # D-NXKT: towrope exists
  if ( getprop("sim/glider/towrope/flags/exist") != 1 ) {   # does the towing rope exist?
    set_hook_coordinates(2);	    # D-NXKT: set glider hook coordinates
    ### place towing rope at nose of glider and scale it to distance to dragger
    # place towing rope at hook of glider and scale it to distance to dragger
    var rope_length_m = getprop("sim/glider/towing/conf/rope_length_m");
    ###  var rope_distance_m = rope_length_m * (getprop("sim/glider/towing/conf/rope_x1") - 0.02);
    var rope_distance_m = rope_length_m ;

    var install_distance_m = 0.05; # 0.05m in front of ref-point of glider
    
    # local variables
    var ac_pos = geo.aircraft_position();		    # get position of aircraft
    var ac_hd  = getprop("orientation/heading-deg");	    # get heading of aircraft
    var ac_pt  = getprop("orientation/pitch-deg");	    # get pitch of aircraft
    var ac_alt_m = getprop("position/altitude-ft") * FT2M;  # get altitude of aircraft
    
    
    var install_alt_m = -0.15; # 0.15m below of ref-point of glider
    
    var rope_pos    = ac_pos.apply_course_distance( ac_hd , install_distance_m );   
    							    # initial rope position, 
    							      # at nose of glider
    rope_pos.set_alt(ac_pos.alt() + install_alt_m);		  # correct hight by pitch
    
    # get the next free ai id and model id
    var freeModelid = getFreeModelID();
    
    var towrope_ai  = props.globals.getNode("ai/models/towrope", 1);
    var towrope_mod = props.globals.getNode("models", 1);
    var towrope_sim = props.globals.getNode("sim/glider/towrope/data", 1);
    var towrope_flg = props.globals.getNode("sim/glider/towrope/flags", 1);
    
    towrope_sim.getNode("id_AI", 1).setIntValue(9998);
    towrope_sim.getNode("id_model", 1).setIntValue(freeModelid);
    towrope_sim.getNode("rope_distance_m", 1).setValue(rope_distance_m);
    towrope_sim.getNode("xstretch_rel", 1).setValue(rope_distance_m / rope_length_m);
    towrope_sim.getNode("rope_heading_deg", 1).setValue(ac_hd);
    towrope_sim.getNode("rope_pitch_deg", 1).setValue(0.0);
    towrope_sim.getNode("hook_x_m", 1).setValue(install_distance_m);
    towrope_sim.getNode("hook_z_m", 1).setValue(install_alt_m);
    
    towrope_flg.getNode("exist", 1).setIntValue(1);
    
    towrope_ai.getNode("id", 1).setIntValue(9998);
    towrope_ai.getNode("callsign", 1).setValue("towrope");
    towrope_ai.getNode("valid", 1).setBoolValue(1);
    towrope_ai.getNode("position/latitude-deg", 1).setValue(rope_pos.lat());
    towrope_ai.getNode("position/longitude-deg", 1).setValue(rope_pos.lon());
    towrope_ai.getNode("position/altitude-ft", 1).setValue(rope_pos.alt() * M2FT);
    towrope_ai.getNode("orientation/true-heading-deg", 1).setValue(ac_hd);
    towrope_ai.getNode("orientation/pitch-deg", 1).setValue(0);
    towrope_ai.getNode("orientation/roll-deg", 1).setValue(0);
    
    towrope_mod.model = towrope_mod.getChild("model", freeModelid, 1);
    towrope_mod.model.getNode("path", 1).setValue("Aircraft/asw20/Models/Ropes/towingrope.xml");
    towrope_mod.model.getNode("longitude-deg-prop", 1).setValue(
    	  "ai/models/towrope/position/longitude-deg");
    towrope_mod.model.getNode("latitude-deg-prop", 1).setValue(
    	  "ai/models/towrope/position/latitude-deg");
    towrope_mod.model.getNode("elevation-ft-prop", 1).setValue(
    	  "ai/models/towrope/position/altitude-ft");
    towrope_mod.model.getNode("heading-deg-prop", 1).setValue(
    	  "ai/models/towrope/orientation/true-heading-deg");
    towrope_mod.model.getNode("roll-deg-prop", 1).setValue(
    	  "ai/models/towrope/orientation/roll-deg");
    towrope_mod.model.getNode("pitch-deg-prop", 1).setValue(
    	  "ai/models/towrope/orientation/pitch-deg");
    towrope_mod.model.getNode("load", 1).remove();
  }
  else{
      #atc_msg("towing rope already exist");
  }
  
}



# ####################################################################################
# update the towing rope in the model property tree
var updateTowingRope = func {
# functions from geo.nas
#     .course_to(<coord>)         ... returns course to another geo.Coord instance (degree)
#     .distance_to(<coord>)       ... returns distance in m along Earth curvature, ignoring altitudes
#                                     useful for map distance
#     .direct_distance_to(<coord>)      ...   distance in m direct, considers altitude,
#                                             but cuts through Earth surface
  
  # local variables
  var glider = geo.Coord.new();        # keeps the glider position
  var glider_head_deg = 0;             # keeps heading of glider
  var dragger = geo.Coord.new();       # keeps the dragger position
  var drlat = 0;                       # temporary latitude of dragger
  var drlon = 0;                       # temporary longitude of dragger
  var dralt = 0;                       # temporary altitude of dragger
  var distance = 0;                    # distance glider to dragger
  var dragheadto = 0;                  # heading to dragger
  var dragpitchto = 0;                 # pitch to dragger
  var aiobjects = [];                  # keeps the ai-planes from the property tree
  var dragid = 0;                      # id of dragger
  var install_distance_m = 0.15;
  var install_alt_m = -0.15;
    
  glider = geo.aircraft_position();
  glider_head_deg = getprop("orientation/heading-deg");

  ############################################# D-NXKT: glider hook coordinates ######################################

  # set hook coordinates
  set_hook_coordinates(2);

  # hook coordinates in FDM-system
  var x = getprop("sim/asw20/hook/hook_x_m");
  var y = getprop("sim/asw20/hook/hook_y_m");
  var z = getprop("sim/asw20/hook/hook_z_m");

  var alpha_deg = getprop("orientation/roll-deg") * (-1.);
  var beta_deg  = getprop("orientation/pitch-deg");
  var gamma_deg = 0. ;

  # transform hook coordinates
  var Xn = PointRotate3D(x:x,y:y,z:z,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:gamma_deg);

  var install_distance_m = -Xn[0]; # in front of ref-point of glider
  var install_side_m     = -Xn[1];
  var install_alt_m      =  Xn[2];  
    
  var rope_pos    = glider.apply_course_distance( glider_head_deg , install_distance_m ); 
  var rope_pos    = glider.apply_course_distance( glider_head_deg - 90. , install_side_m );  # D-NXKT  
  rope_pos.set_alt(glider.alt() + install_alt_m); 
  
  ####################################################################################################################
  
  dragid = getprop("sim/glider/towing/dragid");        # id of former found dragger
  
  aiobjects = props.globals.getNode("ai/models").getChildren(); 
  foreach (var aimember; aiobjects) { 
    if ( (var c = aimember.getNode("id") ) != nil ) { 
      var testprop = c.getValue();
      if ( testprop == dragid ) {
        # get coordinates
        drlat = aimember.getNode("position/latitude-deg").getValue(); 
        drlon = aimember.getNode("position/longitude-deg").getValue(); 
        dralt = (aimember.getNode("position/altitude-ft").getValue()) * FT2M; 
        draggerpitch_deg = aimember.getNode("orientation/pitch-deg").getValue();
        draggerroll_deg = aimember.getNode("orientation/roll-deg").getValue();
        draggerhead_deg = aimember.getNode("orientation/true-heading-deg").getValue();     
      }
    }
  }

  ############################################# D-NXKT: dragger hook coordinates #####################################
  
  dragger = geo.Coord.set_latlon( drlat, drlon, dralt ); # position of current plane
  
  # hook coordinates in FDM-system
  var draggerHookX = - getprop("sim/hitches/dragger/local-pos-x");
  var draggerHookY = getprop("sim/hitches/dragger/local-pos-y");
  var draggerHookZ = getprop("sim/hitches/dragger/local-pos-z");

  var alpha_deg = draggerroll_deg * (-1.);
  var beta_deg  = draggerpitch_deg;	 
  var gamma_deg = 0. ;

  # transform hook coordinates
  var Xn = PointRotate3D(x:draggerHookX,y:draggerHookY,z:draggerHookZ,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:gamma_deg);

  var install_distance_m =  -Xn[0]; # in front of ref-point of glider  
  var install_side_m     =  -Xn[1];
  var install_alt_m      =  Xn[2];  

  var draggerHook_pos    = dragger.apply_course_distance( draggerhead_deg , install_distance_m ); 
  var draggerHook_pos    = dragger.apply_course_distance( draggerhead_deg - 90. , install_side_m );   
  draggerHook_pos.set_alt(dragger.alt() + install_alt_m); 

  ####################################################################################################################
    
  distance = (rope_pos.direct_distance_to(draggerHook_pos));      # distance to plane in meter
  dragheadto = (rope_pos.course_to(draggerHook_pos));
  var height = rope_pos.alt() - draggerHook_pos.alt();
  #  print(" hoehe: ", height);
  ###if ( glider.alt() > dragger.alt() ) {                                          # D-NXKT
  ###  dragpitchto = -math.asin((glider.alt()-dragger.alt())/distance) / 0.01745;   # D-NXKT
  ###}                                                                              # D-NXKT
  ###else {                                                                         # D-NXKT
  ###  dragpitchto =  -math.asin((glider.alt()-dragger.alt())/distance) / 0.01745;  # D-NXKT
  ###}                                                                              # D-NXKT
  dragpitchto = -math.asin((rope_pos.alt()-draggerHook_pos.alt())/distance) / 0.01745;  # D-NXKT
  #  print("  pitch: ", dragpitchto);
  
  # update position of rope
  setprop("ai/models/towrope/position/latitude-deg", rope_pos.lat());
  setprop("ai/models/towrope/position/longitude-deg", rope_pos.lon());
  setprop("ai/models/towrope/position/altitude-ft", rope_pos.alt() * M2FT);
  
  # update length of rope
  setprop("sim/glider/towrope/data/xstretch_rel", distance);
  
  # update pitch and heading of rope
  setprop("sim/glider/towrope/data/rope_heading_deg", dragheadto);
  setprop("sim/glider/towrope/data/rope_pitch_deg", 0);
  setprop("ai/models/towrope/orientation/true-heading-deg", dragheadto);
  setprop("ai/models/towrope/orientation/pitch-deg", dragpitchto);

}



# ####################################################################################
# dummy function to delete the towing rope
var removeTowingRope = func {
  
  # look for allready existing ai object with callsign "towrope"
  # check for the towing rope is still existent
  # if yes, 
  #   remove the towing rope from the property tree ai/models
  #   remove the towing rope from the property tree models/
  #   remove the towing rope working properties
  # if no, 
  #   do nothing
  
  # local variables
  var modelsNode = {};
  
  if ( getprop("sim/glider/towrope/flags/exist") == 1 ) {   # does the towing rope exist?
    # remove 3d model from scenery
    # identification is /models/model[x] with x=id_model
    var id_model = getprop("sim/glider/towrope/data/id_model");
    modelsNode = "models/model[" ~ id_model ~ "]";
    props.globals.getNode(modelsNode).remove();
    props.globals.getNode("ai/models/towrope").remove();
    props.globals.getNode("/sim/glider/towrope/data").remove();
    #atc_msg("towing rope removed");
    setprop("/sim/glider/towrope/flags/exist", 0);
  }
  else {                                                     # do nothing
    #atc_msg("towing rope does not exist");
  }
  
}



# ################################## D-NXKT ##########################################
# set multiplayer variables needed for yasim-draggers
#
var setMultiplayerVariables = func {
      props.globals.getNode("sim/hitches/aerotow/tow/length", 1).setValue( getprop("sim/glider/towing/conf/rope_length_m") );
      setprop("sim/hitches/aerotow/tow/elastic-constant", getprop("sim/glider/towing/conf/rope_characteristics") );
      setprop("sim/hitches/aerotow/tow/weight-per-m-kg-m", 0.04);
      setprop("sim/hitches/aerotow/tow/brake-force", getprop("sim/glider/towing/conf/breaking_towforce_N") );
      props.globals.getNode("sim/hitches/aerotow/is-slave", 1).setBoolValue(0);
      setprop("sim/hitches/aerotow/speed-in-tow-direction", 0.);

      setprop("sim/hitches/aerotow/local-pos-x", getprop("sim/asw20/hook/hook_x_m") );   # Different orientation in Yasim?
      setprop("sim/hitches/aerotow/local-pos-y", getprop("sim/asw20/hook/hook_y_m") );
      setprop("sim/hitches/aerotow/local-pos-z", getprop("sim/asw20/hook/hook_z_m") );
            
      setprop("sim/hitches/aerotow/tow/end-force-x", 0.);    
      setprop("sim/hitches/aerotow/tow/end-force-y", 0.);    
      setprop("sim/hitches/aerotow/tow/end-force-z", 0.);    

      setprop("sim/hitches/aerotow/tow/connected-to-property-node", getprop("sim/glider/towing/dragid") );
      setprop("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign", getprop("sim/glider/towing/dragcallsign") );
 
    
      #############################################  Info  #########################################
      # below all transmitted properties are listed:
      # setprop("sim/hitches/aerotow/tow/elastic-constant", elastic_constant);
      # setprop("sim/hitches/aerotow/tow/weight-per-m-kg-m", 0.04);
      # setprop("sim/hitches/aerotow/tow/dist", distance);
      # setprop("sim/hitches/aerotow/tow/connected-to-property-node", dragid); 	
      # setprop("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign", callsign);	
      # setprop("sim/hitches/aerotow/tow/brake-force", getprop("sim/glider/towing/conf/breaking_towforce_N") );
      # setprop("sim/hitches/aerotow/tow/end-force-x", fgx);      # force in N / cartesian world coordinates
      # setprop("sim/hitches/aerotow/tow/end-force-y", fgy);      # force in N / cartesian world coordinates
      # setprop("sim/hitches/aerotow/tow/end-force-z", fgz);      # force in N / cartesian world coordinates
      # setprop("sim/hitches/aerotow/is-slave", 0);		  # not needed for JSBSim
      # setprop("sim/hitches/aerotow/speed-in-tow-direction", );  # not (yet) needed for JSBSim
      # setprop("sim/hitches/aerotow/open", open);		 
      # setprop("sim/hitches/aerotow/local-pos-x", getprop("sim/asw20/hook/hook_x_m") );   # Different orientation in Yasim!
      # setprop("sim/hitches/aerotow/local-pos-y", getprop("sim/asw20/hook/hook_y_m") );
      # setprop("sim/hitches/aerotow/local-pos-z", getprop("sim/asw20/hook/hook_z_m") );      
      ##############################################################################################  
 
 } # End Function setMultiplayerVariables



# ####################################################################################
# hookDragger
# used by key
# used by gui
var hookDragger = func {
  
  # if dragid > 0
  #  set property /fdm/jsbsim/fcs/dragger-cmd-norm
  #  level plane

  if ( getprop("sim/glider/towing/dragid") != nil ) { 
    set_hook_coordinates(2);   # set ASW20 hook coordinates
    setMultiplayerVariables(); # D-NXKT
    props.globals.getNode("sim/hitches/aerotow/open", 1).setBoolValue(0);  # D-NXKT: close the "multiplayer hook"
    pilot_msg("%s, I am on your hook, distance %4.3f meter.",getprop("sim/multiplay/callsign"),getprop("sim/hitches/aerotow/tow/dist"));
    # waiting until dragger has reported a closed hook. Otherwise the glider hook will be released immediately in func runDragger
    var running = 1;
    var loop = func {
      if (running) {
        dragid = getprop("sim/glider/towing/dragid");    # id of former found dragger
        aiobjects = props.globals.getNode("ai/models").getChildren(); 
        foreach (var aimember; aiobjects) { 
          if ( (var c = aimember.getNode("id") ) != nil ) { 
            var testprop = c.getValue();
            if ( testprop == dragid ) {
	      if ( (var d = aimember.getNode("sim/hitches/aerotow/open") ) != nil ) {
	        var draggerOpen = aimember.getNode("sim/hitches/aerotow/open").getValue(); 
 		if ( draggerOpen == nil){    # we have found an MP-plane without interactive towing capability
		  #print('MP-plane without interactive towing capability');
		  draggerOpen = 0; 
		  props.globals.getNode("sim/hitches/aerotow/open", 1).setBoolValue(0);  # otherwise glider hook releases immediately
		}
		else {  #if the node already exists from a previous dragger, this messages also appears for "non-interactiv MP-planes
                  if ( aimember.getNode("sim/hitches/aerotow/tow/dist").getValue() > 0.){      # only needed for interactive MP-dragger
		    #atc_msg("Waiting for dragger response"); 
		    dragger_msg("%s: Just a second, please! I am trying to close my hook!",getprop("sim/glider/towing/dragcallsign"));
		  }
		  else{
		    setprop("sim/hitches/dragger/mp_last_reported_dist", -1.)
		  }
		}
              # get dragger hook coordinates  
              var draggerHookX = aimember.getNode("sim/hitches/aerotow/local-pos-x").getValue();
              var draggerHookY = aimember.getNode("sim/hitches/aerotow/local-pos-y").getValue();
              var draggerHookZ = aimember.getNode("sim/hitches/aerotow/local-pos-z").getValue();
	      setprop("sim/hitches/dragger/local-pos-x",draggerHookX);
	      setprop("sim/hitches/dragger/local-pos-y",draggerHookY);
	      setprop("sim/hitches/dragger/local-pos-z",draggerHookZ);
	      }
	      else{      #AI-plane
	        #print('AI-plane');
	      	draggerOpen = 0;
		props.globals.getNode("sim/hitches/aerotow/open", 1).setBoolValue(0);  # otherwise glider hook releases immediately	  
              }
	    }  
          }
        }
        if(draggerOpen == 0){
          # now the dragger transmitted a closed hook 
          createTowingRope();                                 # create rope model
          setprop("fdm/jsbsim/fcs/dragger-cmd-norm", 1);      # closes the hook      
          setprop("sim/glider/towing/hooked", 1);             # this starts the towing function
          #atc_msg("hook closed");
          setprop("orientation/roll-deg", 0); 
          #atc_msg("glider leveled"); 
	  if ( getprop("sim/hitches/dragger/mp_last_reported_dist") > 0.){      # only needed for interactive MP-dragger
            dragger_msg("%s: Success! Hook closed!",getprop("sim/glider/towing/dragcallsign"));
	    #pilot_msg("%s, I am on your hook, distance %4.3f meter.",getprop("sim/multiplay/callsign"),getprop("sim/hitches/aerotow/tow/dist"));
	  }    
          running = 0;   # stop loop
        }
      }
 
      settimer(loop, 1);
    }
    loop();        # start loop

  }
  else { 
    #atc_msg("no dragger nearby");
    atc_msg("Sorry, no aircraft for aerotow!"); 
  }
      #setprop("sim/hitches/dragger/mp_last_reported_dist", getprop("sim/hitches/aerotow/tow/dist") );  # initialise value (needed for MP-draggers)
      setprop("sim/hitches/dragger/mp_last_reported_dist", 0. );  # initialise value (needed for MP-draggers)
 

} # End Function hookDragger



# ####################################################################################
# releaseDragger
# used by key
var releaseDragger = func {
  
  # first check for dragger is pulling
  # if yes
  #   opens the hook
  #   sets the forces to zero
  #   print a message
  # if no
  #   print a message
  # exit
  
  if ( getprop ("sim/glider/towing/hooked") ) {
    
    setprop  ("fdm/jsbsim/fcs/dragger-cmd-norm",0);                # opens the hook

    setprop("fdm/jsbsim/external_reactions/dragx/magnitude", 0);   # nose hook forces
    setprop("fdm/jsbsim/external_reactions/dragy/magnitude", 0);   # 
    setprop("fdm/jsbsim/external_reactions/dragz/magnitude", 0);   # 

    setprop("fdm/jsbsim/external_reactions/winchx/magnitude", 0);  # c.g. hook forces
    setprop("fdm/jsbsim/external_reactions/winchy/magnitude", 0);  # 
    setprop("fdm/jsbsim/external_reactions/winchz/magnitude", 0);  # 

    setprop("sim/hitches/aerotow/tow/end-force-x", 0);             # MP tow-end forces 
    setprop("sim/hitches/aerotow/tow/end-force-y", 0);             # 
    setprop("sim/hitches/aerotow/tow/end-force-z", 0);             # 


    setprop("sim/glider/towing/hooked",0);                         # dragger is not pulling
    props.globals.getNode("sim/hitches/aerotow/open").setBoolValue(1); # D-NXKT: needed for multiplayer (Yasim)
    #atc_msg("Hook opened, tow released");
    pilot_msg("Opened hitch!");
    removeTowingRope();                                         # remove towing model
  }
  else {                                             
    #atc_msg("Hook already opened");
    pilot_msg("Hitch already opened");
  }
  
} # End Function releaseDragger



# ####################################################################################
# let the dragger pull the plane up into the sky
var runDragger = func {
  
  # strategy:
  # get current positions and orientations of glider and dragger
  # calculate the forces with respect of distance and spring-coefficient of tow
  # calculate force distribution in main axes
  # do this as long as the tow is engaged at the glider
  
  # local constants describing tow properties
  var tf0 = 0;                         # coresponding force
  # local variables
  var forcex = 0;                      # the force in x-direction, body ref system
  var forcey = 0;                      # the force in y-direction, body ref system
  var forcez = 0;                      # the force in z-direction, body ref system
  var glider = geo.Coord.new();        # keeps the glider position
  var gliderhead = 0;                  # keeps the glider heading
  var gliderpitch = 0;                 # keeps the glider pitch
  var gliderroll = 0;                  # keeps the glider roll
  var dragger = geo.Coord.new();       # keeps the dragger position
  var drlat = 0;                       # temporary latitude of dragger
  var drlon = 0;                       # temporary longitude of dragger
  var dralt = 0;                       # temporary altitude of dragger
  var dragheadto = 0;                  # heading to dragger
  var aiobjects = [];                     # keeps the ai-planes from the property tree
  var distance = 0;                    # distance glider to dragger
  var distancepr = 0;                  # projected distance glider to dragger
  var reldistance = 0;                 # relative distance glider to dragger
  var dragid = 0;                      # id of dragger
  var planeid = 0;                     # id of current processed plane

  var mp_delta_reported_dist = 1.;     # D-NXKT: 0. if MP-dragger properties are not updated (time lag)
  
  var nominaltowforce = getprop("sim/glider/towing/conf/nominal_towforce_lbs");
  var breakingtowforce = getprop("sim/glider/towing/conf/breaking_towforce_N") * 0.224809; # D-NXKT: N -> lbs
  var towlength_m = getprop("sim/glider/towing/conf/rope_length_m");
  var tl0 = getprop("sim/glider/towing/conf/rope_x1");
  var ropetype = getprop("sim/glider/towing/conf/rope_characteristics");

  var hook_in_use = getprop("sim/asw20/hook/hook-in-use");   # D-NXKT
  
  # do all the stuff
  if ( getprop("sim/glider/towing/hooked") == 1 ) {          # is a dragger engaged
    
    glider = geo.aircraft_position();                        # current glider position
    gliderpitch = getprop("orientation/pitch-deg");
    gliderroll = getprop("orientation/roll-deg");
    gliderhead = getprop("orientation/heading-deg");
    
    ############################################# D-NXKT: glider hook coordinates ######################################

    # set hook coordinates
    set_hook_coordinates(2);

    # hook coordinates in FDM-system
    var x = getprop("sim/asw20/hook/hook_x_m");
    var y = getprop("sim/asw20/hook/hook_y_m");
    var z = getprop("sim/asw20/hook/hook_z_m");

    var alpha_deg = gliderroll * (-1.);
    var beta_deg  = gliderpitch;
    var gamma_deg = 0. ;

    # transform hook coordinates
    var Xn = PointRotate3D(x:x,y:y,z:z,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:gamma_deg);
    var install_distance_m = -Xn[0]; # in front of ref-point of glider
    var install_side_m     = -Xn[1];
    var install_alt_m      =  Xn[2];  
    
    var rope_pos    = glider.apply_course_distance( gliderhead , install_distance_m ); 
    var rope_pos    = glider.apply_course_distance( gliderhead - 90. , install_side_m );  # D-NXKT  
    rope_pos.set_alt(glider.alt() + install_alt_m); 

    # transform glider hook coordinates to cartesian earth coordinates
    var GliderHookCartEarth = geodtocart(rope_pos.lat(),rope_pos.lon(),rope_pos.alt() );
    var gliderXearth_m = GliderHookCartEarth[0];
    var gliderYearth_m = GliderHookCartEarth[1];
    var gliderZearth_m = GliderHookCartEarth[2];

    ####################################################################################################################

    dragid = getprop("sim/glider/towing/dragid");        # id of former found dragger
    
    aiobjects = props.globals.getNode("ai/models").getChildren(); 
    foreach (var aimember; aiobjects) { 
      if ( (var c = aimember.getNode("id") ) != nil ) { 
        var testprop = c.getValue();
        if ( testprop == dragid ) {
          # get coordinates
          drlat = aimember.getNode("position/latitude-deg").getValue(); 
          drlon = aimember.getNode("position/longitude-deg").getValue(); 
          dralt = (aimember.getNode("position/altitude-ft").getValue()) * FT2M;
	  draggerpitch_deg = aimember.getNode("orientation/pitch-deg").getValue();
          draggerroll_deg = aimember.getNode("orientation/roll-deg").getValue();
          draggerhead_deg = aimember.getNode("orientation/true-heading-deg").getValue();     

          #################################  D-NXKT  #####################################
	  # is the (multiplayer) dragger hook open or closed?  				 
	  if ( (var d = aimember.getNode("sim/hitches/aerotow/open") ) != nil ) {
	    var draggerOpen = aimember.getNode("sim/hitches/aerotow/open").getValue(); 
	    #print('draggerOpen=',draggerOpen); 
	    if ( draggerOpen == 1 ) {		  
	      releaseDragger();  						  
              #atc_msg(" Dragger has released!");
	      dragger_msg("%s: I have released the tow!",getprop("sim/glider/towing/dragcallsign"));
	      break;					  
	    }
	  }
	  # check if the dragger properties have been updated
	  if ( (var d = aimember.getNode("sim/hitches/aerotow/tow/dist") ) != nil ) {  
	    var mp_reported_dist = aimember.getNode("sim/hitches/aerotow/tow/dist").getValue();
	    #print('mp_reported_dist=',mp_reported_dist);
	    var mp_last_reported_dist = getprop("sim/hitches/dragger/mp_last_reported_dist");
	    #print('mp_last_reported_dist=',mp_last_reported_dist);
	    var mp_delta_reported_dist = mp_reported_dist - mp_last_reported_dist ;	     
	    #print('mp_delta_reported_dist=',mp_delta_reported_dist);
	    mp_last_reported_dist = mp_reported_dist ;
	    setprop("sim/hitches/dragger/mp_last_reported_dist",mp_last_reported_dist);
	  } 	    
          ################################################################################
        }
      }
    }
    var mp_delta_reported_dist2 = mp_delta_reported_dist  * mp_delta_reported_dist ;      # D-NXKT: we need the absolute value
    if ( (mp_delta_reported_dist2 > 0.0000001) or (mp_reported_dist < 0. )){ 
      # we have the updated dragger coordinates (no time lag) or the dragger is a non-interactive mp plane  => update forces                                       # else use the old forces!      
    

    ############################################# D-NXKT: dragger hook coordinates #####################################

    dragger = geo.Coord.set_latlon( drlat, drlon, dralt ); # position of current plane
    
    # hook coordinates in FDM-system
    var draggerHookX = - getprop("sim/hitches/dragger/local-pos-x"); 
    var draggerHookY = getprop("sim/hitches/dragger/local-pos-y");
    var draggerHookZ = getprop("sim/hitches/dragger/local-pos-z");

    var alpha_deg = draggerroll_deg * (-1.);
    var beta_deg  = draggerpitch_deg;	 
    var gamma_deg = 0. ;

    # transform hook coordinates
    var Xn = PointRotate3D(x:draggerHookX,y:draggerHookY,z:draggerHookZ,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:gamma_deg);

    var install_distance_m =  -Xn[0];   
    var install_side_m     =  -Xn[1];
    var install_alt_m      =   Xn[2];  

    var draggerHook_pos    = dragger.apply_course_distance( draggerhead_deg , install_distance_m ); 
    var draggerHook_pos    = dragger.apply_course_distance( draggerhead_deg - 90. , install_side_m );   
    draggerHook_pos.set_alt(dragger.alt() + install_alt_m); 

    var DraggerHookCartEarth = geodtocart(dragger.lat(),dragger.lon(),dragger.alt());
    var draggerXearth_m = DraggerHookCartEarth[0];
    var draggerYearth_m = DraggerHookCartEarth[1];
    var draggerZearth_m = DraggerHookCartEarth[2];
    
    ####################################################################################################################
   
    distance = (rope_pos.direct_distance_to(draggerHook_pos));      # distance to plane in meter
    distancepr = (rope_pos.distance_to(draggerHook_pos));
    dragheadto = (rope_pos.course_to(draggerHook_pos));
    reldistance = distance / towlength_m;
    
    ### if ( reldistance < tl0 ) {
    ###  if ( reldistance < 1 ) {
    ###   forcetow = tf0;
    ### }
    ### else {
    ###   forcetow = math.pow((reldistance - tl0),ropetype) 
    ### 	     / math.pow((1-tl0),ropetype) * nominaltowforce;
    ###   forcetow = ( distance - towlength_m ) * 100 ;      # ropetype;
    ###   print(" forcetow ", forcetow , "  distance ", distance,"  ", breakingtowforce);
    ### }


    # var tow_rope_factor = Youngs-Modulus * cross-section-aerea / towlength_m * 0.001;  # D-NXKT: calculate once only in gui!
    ### force in lbs

    var elastic_constant = getprop("sim/glider/towing/conf/rope_characteristics");
    var delta_towlength_m = distance - towlength_m;
    if ( delta_towlength_m < 0. ) {
      forcetow_N = 0.;
    }
    else{
      forcetow_N = elastic_constant * delta_towlength_m / towlength_m;
    }
    forcetow = forcetow_N * 0.224809;   # D-NXKT: N -> LBF     

    # print(" forcetow_N ", forcetow_N , "  distance ", distance,"  ", breakingtowforce);

    if ( forcetow < breakingtowforce ) {
      
      # correct a failure, if the projected length is larger than direct length
      if (distancepr > distance) { distancepr = distance;} 
           
      var alpha = math.acos( (distancepr / distance) );
      var beta = ( dragheadto - gliderhead ) * 0.01745;
      var gamma = gliderpitch * 0.01745;
      var delta = gliderroll * 0.01745;
      
      
      var sina = math.sin(alpha);
      var cosa = math.cos(alpha);
      var sinb = math.sin(beta);
      var cosb = math.cos(beta);
      var sing = math.sin(gamma);
      var cosg = math.cos(gamma);
      var sind = math.sin(delta);
      var cosd = math.cos(delta);
      
      # global forces: alpha beta
      var fglobalx = forcetow * cosa * cosb;
      var fglobaly = forcetow * cosa * sinb;
      var fglobalz = forcetow * sina;
      if ( dragger.alt() > glider.alt()) {
        fglobalz = -fglobalz;
      }
            
      # local forces by pitch: gamma
      var flpitchx = fglobalx * cosg - fglobalz * sing;
      var flpitchy = fglobaly;
      var flpitchz = fglobalx * sing + fglobalz * cosg;
            
      # local forces by roll: delta
      var flrollx  = flpitchx;
      var flrolly  = flpitchy * cosd + flpitchz * sind;
      var flrollz  = flpitchy * sind + flpitchz * cosd;
      
      # asigning to LOCAL coord of plane
      var forcex = flrollx;
      var forcey = flrolly;
      var forcez = flrollz;
      
      # apply forces to clutch (forces are in LBS)
      if(hook_in_use == 0 or hook_in_use == 2) {                             # D-NXKT: nose hook       
        setprop("fdm/jsbsim/external_reactions/dragx/magnitude",  forcex);
        setprop("fdm/jsbsim/external_reactions/dragy/magnitude",  forcey);
        setprop("fdm/jsbsim/external_reactions/dragz/magnitude",  forcez);
      }
      else{                                                                  # D-NXKT: c.g. hook 
        setprop("fdm/jsbsim/external_reactions/winchx/magnitude",  forcex );  
        setprop("fdm/jsbsim/external_reactions/winchy/magnitude",  forcey );  
        setprop("fdm/jsbsim/external_reactions/winchz/magnitude",  forcez );   
      }
      
      # keep the glider leveled up to a certain speed
      # thanks to the helper, who holds the left wing tip
      var spd_ground_mps = getprop("velocities/groundspeed-kt") * KT2MPS;
      if (spd_ground_mps < 5 ) {
        setprop("orientation/roll-deg", 0);
      }

      #############################  D-NXKT: tow forces for MP  ##########################
      
      # calculate normal vector in tow direction in cartesian earth coordinates
      var dx = draggerXearth_m - gliderXearth_m;
      var dy = draggerYearth_m - gliderYearth_m;
      var dz = draggerZearth_m - gliderZearth_m;
      var dl = math.sqrt( dx * dx + dy * dy + dz * dz );
      
      var forcetowX_N = forcetow_N * dx / dl;
      var forcetowY_N = forcetow_N * dy / dl;
      var forcetowZ_N = forcetow_N * dz / dl;
      
      setprop("sim/hitches/aerotow/tow/dist", distance);
      setprop("sim/hitches/aerotow/tow/end-force-x", -forcetowX_N); # force acts in 
      setprop("sim/hitches/aerotow/tow/end-force-y", -forcetowY_N); # opposite direction  
      setprop("sim/hitches/aerotow/tow/end-force-z", -forcetowZ_N); # at tow end
      	    
      ####################################################################################   

    }
    else {
      releaseDragger();
      atc_msg("TOWFORCE EXCEEDED");
    }
    
    } # end update forces
    else { 
      #print("forces NOT updated"); 
    }
      
    # update animated towing rope
    updateTowingRope();


    settimer(runDragger, towing_timeincrement);
    
  }
  
} # End Function runDragger



# ####################################################################################
var dragging = setlistener("sim/glider/towing/hooked", runDragger); 
var initialize_aerotowing = setlistener("sim/signals/fdm-initialized", globalsTowing);
