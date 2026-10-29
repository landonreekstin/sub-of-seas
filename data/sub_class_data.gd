class_name SubClassData
extends Resource
## Balance data for one player submarine class. Speeds in knots, distances in metres.

@export var key := ""
@export var display_name := ""
@export var crew_min := 3
@export var crew_max := 4
@export var length := 95.0
@export var surface_speed_kn := 20.0
@export var submerged_speed_kn := 9.0
@export var acceleration := 0.15 ## m/s²
@export var max_turn_rate := 3.0 ## deg/s at full rudder with way on
@export var max_dive_rate := 0.8 ## m/s
@export var periscope_depth := 18.0 ## keel depth with the scope just clear of the water
@export var test_depth := 90.0
@export var crush_depth := 150.0
@export var bow_tubes := 6
@export var stern_tubes := 4
@export var torpedo_capacity := 24
@export var battery_endurance_min := 30.0 ## minutes submerged at AHEAD 1/3 on a full battery
@export var charge_minutes := 8.0 ## minutes to charge flat to full on both diesels, stopped
