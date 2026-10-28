class_name ShipClassData
extends Resource
## Balance data for one AI surface ship class. See docs/ships.md for the history behind it.

@export var key := "" ## file name in data/ships, used to send the class over the network
@export var display_name := ""
@export var kind := "freighter" ## which model ShipModels builds
@export var length := 120.0
@export var beam := 16.0
@export var max_speed_kn := 12.0
@export var cruise_speed_kn := 9.0
@export var max_turn_rate := 1.5 ## deg/s
@export var hp := 2.0 ## in torpedo hits
@export var tonnage := 6000
@export var zigzag_angle := 15.0 ## degrees either side of base course
@export var sink_time := 60.0 ## seconds from fatal hit to gone

@export_group("Anti-submarine")
@export var asw := false ## hunts subs (has sonar and depth charges)
@export var lookout_range := 3500.0 ## m at which lookouts can spot a raised periscope
@export var hydrophone_range := 0.0 ## m at which it can hear a sub at flank speed
@export var sonar_range := 0.0 ## m of its active sonar (0 = none)
@export var ping_interval := 6.0 ## s between pings while searching or hunting
@export var depth_charges := 0
@export var dc_pattern := 6 ## charges per attack run
@export var depth_error := 15.0 ## m of error when it sets charge depth
@export var hunt_speed_kn := 24.0
