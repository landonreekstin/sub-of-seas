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
@export var flood_seconds := 30.0 ## main ballast vents open to decks awash
@export var co2_canisters := 8 ## CO2 absorbent canisters aboard
@export var spare_parts := 6 ## spare-parts boxes in stores
@export_group("Deck gun")
@export var gun_name := "4-inch/50" ## shown on the gun station
@export var gun_rounds := 80 ## rounds in the magazine
@export var gun_ready := 8 ## ready-use rounds at the gun; more have to be passed up
@export var gun_damage := 0.15 ## a hit, in ship hp (a torpedo is 1)
@export var gun_range := 6000.0 ## m, the most the sight is graduated to
@export var gun_reload := 3.0 ## s between rounds
@export_group("")
## Suggested jobs, most important first: player N is offered roles[N-1]. Not locks.
@export var roles: Array[String] = []
