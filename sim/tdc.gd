class_name Tdc
## The Torpedo Data Computer, simplified. Periscope marks (time, own position, true
## bearing, stadimeter range) become an estimate of the target's track; the operator can
## nudge its speed and course; the intercept for a straight-running torpedo gives the gyro
## angle. Pure functions over plain data so the host, the station and tests share them.

const MIN_SPAN := 30.0 ## seconds between first and last mark before speed is worked out
const DEFAULT_SPEED_KN := 8.0 ## assumed until two marks give one
const MAX_GYRO := 90.0


## A mark as stored in crew state: plain floats so it replicates.
static func make_mark(t: float, own: Vector2, bearing: float, range_m: float) -> Dictionary:
	return {"t": t, "x": own.x, "y": own.y, "b": bearing, "r": range_m}


static func mark_pos(m: Dictionary) -> Vector2:
	var rad := deg_to_rad(float(m.b))
	return Vector2(m.x, m.y) + Vector2(sin(rad), cos(rad)) * float(m.r)


## {ok, pos (at t), t, vel, course, speed_kn, measured (bool: from two marks)}.
static func estimate(marks: Array, speed_adj_kn := 0.0, course_adj := 0.0) -> Dictionary:
	if marks.is_empty():
		return {"ok": false}
	var last: Dictionary = marks[-1]
	var first: Dictionary = marks[0]
	var span: float = float(last.t) - float(first.t)
	var course := 0.0
	var speed_kn := DEFAULT_SPEED_KN
	var measured := false
	var at_last := mark_pos(last)
	if marks.size() >= 2 and span >= MIN_SPAN:
		# Least-squares straight track through every mark: more marks, less stadimeter error.
		var t0 := float(first.t)
		var st := 0.0
		var stt := 0.0
		var sp := Vector2.ZERO
		var stp := Vector2.ZERO
		for m: Dictionary in marks:
			var t := float(m.t) - t0
			var p := mark_pos(m)
			st += t
			stt += t * t
			sp += p
			stp += p * t
		var n := float(marks.size())
		var v := (stp * n - sp * st) / (stt * n - st * st)
		at_last = (sp - v * st) / n + v * (float(last.t) - t0)
		speed_kn = v.length() / SubState.KNOT
		course = rad_to_deg(atan2(v.x, v.y))
		measured = true
	else:
		# One mark: assume he steams across our line of sight, left to right as seen.
		course = float(last.b) + 90.0
	course = fposmod(course + course_adj, 360.0)
	speed_kn = maxf(0.0, speed_kn + speed_adj_kn)
	var rad := deg_to_rad(course)
	return {
		"ok": true, "pos": at_last, "t": float(last.t), "course": course, "speed_kn": speed_kn,
		"vel": Vector2(sin(rad), cos(rad)) * speed_kn * SubState.KNOT, "measured": measured,
	}


## Where the estimate puts the target at time `now`.
static func target_at(est: Dictionary, now: float) -> Vector2:
	return est.pos + est.vel * (now - float(est.t))


## Intercept for a torpedo fired now from `launch` on a boat heading `heading`.
## {ok, gyro, run (m), range (m), aob (deg, + starboard), reason}.
static func solve(est: Dictionary, now: float, launch: Vector2, heading: float) -> Dictionary:
	if not est.get("ok", false):
		return {"ok": false, "reason": "NO MARKS"}
	var p := target_at(est, now) - launch
	var v: Vector2 = est.vel
	var s := Torpedo.SPEED
	# |p + v t| = s t  ->  (v.v - s²) t² + 2 p.v t + p.p = 0
	var a := v.dot(v) - s * s
	var b := 2.0 * p.dot(v)
	var c := p.dot(p)
	var disc := b * b - 4.0 * a * c
	var out := {"ok": false, "range": p.length(), "aob": _aob(est, p)}
	if disc < 0.0:
		out.reason = "TARGET TOO FAST"
		return out
	var t := (-b - sqrt(disc)) / (2.0 * a)
	if t < 0.0:
		t = (-b + sqrt(disc)) / (2.0 * a)
	var hit := p + v * t
	out.run = hit.length()
	var brg := rad_to_deg(atan2(hit.x, hit.y))
	out.gyro = wrapf(brg - heading, -180.0, 180.0)
	if out.run > Torpedo.MAX_RANGE:
		out.reason = "OUT OF RANGE (%d m run)" % roundi(out.run)
	elif absf(out.gyro) > MAX_GYRO:
		out.reason = "GYRO OVER %d° — TURN THE BOAT" % roundi(MAX_GYRO)
	else:
		out.ok = true
		out.reason = ""
	return out


## Angle on the bow: where we sit relative to the target's bow, + to his starboard.
static func _aob(est: Dictionary, rel: Vector2) -> float:
	var from_target := rad_to_deg(atan2(-rel.x, -rel.y))
	return wrapf(from_target - float(est.course), -180.0, 180.0)


## How much to trust the solution, 0..1: more marks, longer between them, closer in.
static func quality(marks: Array, range_m: float) -> float:
	if marks.is_empty():
		return 0.0
	var span: float = float(marks[-1].t) - float(marks[0].t)
	var q := 0.15
	if marks.size() >= 2 and span >= MIN_SPAN:
		q = 0.4 + minf(0.25, (span - MIN_SPAN) / 60.0 * 0.25) + minf(0.15, (marks.size() - 2) * 0.05)
	q += clampf((3000.0 - range_m) / 2000.0, 0.0, 1.0) * 0.2
	return clampf(q, 0.0, 1.0)
