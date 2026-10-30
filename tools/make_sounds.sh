#!/bin/sh
# Synthesises every sound effect in assets/audio/ with sox (run from the project root).
# Loops end in *_loop.wav and are cut to whole cycles so they repeat cleanly.
set -e
A=assets/audio
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
R="-r 44100 -c 1 -b 16"

# Our own active sonar: a clean 1.5 kHz ping with a long ringing tail.
sox -n $R $A/sonar_ping.wav synth 0.25 sine 1500 fade q 0.005 0.25 0.2 reverb 70 50 100 pad 0 1.5 gain -n -3
# Their echo-ranging finding the hull: higher, harsher, a metallic double hit.
sox -n $R $T/e1.wav synth 0.12 sine 2600 sine 2603 fade q 0.002 0.12 0.1
sox $T/e1.wav $T/e1.wav $R $A/echo_ranging.wav pad 0 0.05 reverb 40 30 60 pad 0 0.8 gain -n -2
# Depth charge: a low thump then a long rumbling roll.
sox -n $R $T/b1.wav synth 2.5 brownnoise lowpass 160 fade q 0.01 2.5 2.2 gain -n -1
sox -n $R $T/b2.wav synth 0.4 sine 45 fade q 0.005 0.4 0.35
sox -m $T/b1.wav $T/b2.wav $R $A/depth_charge.wav reverb 60 50 100 gain -n -1
# A distant torpedo hit heard through the water: a soft deep boom.
sox -n $R $A/torpedo_hit.wav synth 1.8 brownnoise lowpass 90 fade q 0.02 1.8 1.6 reverb 80 gain -n -4
# Shell hit on the hull: a sharp bang with a ringing clang.
sox -n $R $T/s1.wav synth 0.15 whitenoise lowpass 2500 fade q 0.001 0.15 0.14
sox -n $R $T/s2.wav synth 0.9 sine 310 sine 470 fade q 0.001 0.9 0.85 gain -8
sox -m $T/s1.wav $T/s2.wav $R $A/shell_hit.wav gain -n -1
# Splashes of a pattern going in (sonar only): a hollow plop.
sox -n $R $A/splash.wav synth 0.35 pinknoise bandpass 600 300 fade q 0.01 0.35 0.3 gain -n -4
# Torpedo launch: a compressed-air thump and a whoosh.
sox -n $R $T/t1.wav synth 0.25 sine 70 fade q 0.002 0.25 0.2
sox -n $R $T/t2.wav synth 0.9 pinknoise highpass 400 fade q 0.05 0.9 0.7 gain -10
sox -m $T/t1.wav $T/t2.wav $R $A/torpedo_launch.wav gain -n -2
# Hull creaks: slow metal groans, three variants.
for i in 1 2 3; do
  f=$((60 + i * 25))
  sox -n $R $A/creak_$i.wav synth 1.6 sawtooth $f-$((f + 12 * i)) lowpass 400 tremolo $((3 + i)) 60 fade q 0.3 1.6 0.6 reverb 50 gain -n -8
done
# Dive klaxon: two "ah-OO-gah" blasts.
sox -n $R $T/k1.wav synth 0.55 square 220-330 lowpass 1500 fade q 0.02 0.55 0.08
sox $T/k1.wav $T/k1.wav $R $A/klaxon.wav pad 0 0.15 gain -n -3
# General alarm bell.
sox -n $R $A/alarm.wav synth 0.08 sine 900 sine 1350 fade q 0.001 0.08 0.07 repeat 9 gain -n -6
# Loops (whole cycles): diesel chug, electric motor whirr (soft, airy, no hum), water spraying, fire, torch hiss.
sox -n $R $A/diesel_loop.wav synth 2.0 brownnoise lowpass 220 tremolo 12 70 gain -n -6
sox -n $R $A/motor_loop.wav synth 2.0 pinknoise gain -6 highpass 300 lowpass 1500 tremolo 25 12 gain -n -14
sox -n $R $A/water_loop.wav synth 2.0 whitenoise gain -6 highpass 900 lowpass 6000 tremolo 7 20 gain -n -10
sox -n $R $A/fire_loop.wav synth 2.0 brownnoise lowpass 900 tremolo 17 80 gain -n -8
sox -n $R $A/torch_loop.wav synth 2.0 whitenoise gain -6 highpass 2500 gain -n -14

# --- Controls and the crew (M9: everything makes a sound) ---
# Engine telegraph answering bell: two bright dings.
sox -n $R $T/d1.wav synth 0.9 sine 1568 sine 2350 sine 3920 fade q 0.002 0.9 0.85 gain -6
sox $T/d1.wav $R $T/d2.wav trim 0 0.22
sox $T/d2.wav $T/d1.wav $R $A/telegraph_ding.wav gain -n -4
# A big handwheel turning (helm, dive planes): gear-tooth clicks over a soft grind.
sox -n $R $T/w1.wav synth 0.01 whitenoise bandpass 2200 600 fade q 0.001 0.01 0.008
sox $T/w1.wav $R $T/w3.wav pad 0 0.0525
sox $T/w3.wav $R $T/w4.wav repeat 31
sox -n $R $T/w5.wav synth 2.0 brownnoise lowpass 500 tremolo 16 40 gain -18
sox -m $T/w4.wav $T/w5.wav $R $A/wheel_loop.wav trim 0 2.0 gain -n -8
# A heavy lever or valve thrown home: a low clunk with a short metal ring.
sox -n $R $T/l1.wav synth 0.18 sine 95 fade q 0.001 0.18 0.16
sox -n $R $T/l2.wav synth 0.06 whitenoise bandpass 900 400 fade q 0.001 0.06 0.05 gain -4
sox -n $R $T/l3.wav synth 0.5 sine 640 sine 1010 fade q 0.001 0.5 0.48 gain -16
sox -m $T/l1.wav $T/l2.wav $T/l3.wav $R $A/lever.wav gain -n -3
# A small switch, knob or dial detent.
sox -n $R $T/c1.wav synth 0.008 whitenoise bandpass 3200 800 fade q 0.0005 0.008 0.006
sox -n $R $T/c2.wav synth 0.03 sine 1400 fade q 0.001 0.03 0.028 gain -10
sox -m $T/c1.wav $T/c2.wav $R $A/click.wav pad 0 0.05 gain -n -6
# Main ballast vents opening: air roaring out of the tanks, then settling.
sox -n $R $T/v1.wav synth 3.0 whitenoise gain -6 highpass 250 lowpass 3500 fade q 0.08 3.0 2.2
sox -n $R $T/v2.wav synth 3.0 brownnoise lowpass 200 fade q 0.1 3.0 2.4 gain -4
sox -m $T/v1.wav $T/v2.wav $R $A/vent_rush.wav gain -n -3
# Blowing ballast with high-pressure air (loop): a hard, steady hiss.
sox -n $R $A/blow_loop.wav synth 2.0 whitenoise gain -6 highpass 1200 lowpass 7000 tremolo 9 8 gain -n -8
# A thin gas hiss (oxygen bleed), quiet.
sox -n $R $A/hiss_loop.wav synth 2.0 whitenoise gain -6 highpass 3500 tremolo 5 10 gain -n -18
# Periscope hoist (loop): a hydraulic whine with a little grind.
sox -n $R $T/h1.wav synth 2.0 sine 420 sine 433 gain -14
sox -n $R $T/h2.wav synth 2.0 pinknoise bandpass 700 300 tremolo 8 30 gain -16
sox -m $T/h1.wav $T/h2.wav $R $A/hoist_loop.wav gain -n -10
# Sea water flooding a torpedo tube: a deep gurgling rush.
sox -n $R $A/flood.wav synth 2.2 brownnoise bandpass 450 400 tremolo 6 60 fade q 0.15 2.2 1.0 gain -n -4
# A heavy door or hatch shutting: a deep clang.
sox -n $R $T/g1.wav synth 1.3 sine 170 sine 262 sine 415 fade q 0.001 1.3 1.25 gain -6
sox -n $R $T/g2.wav synth 0.08 brownnoise lowpass 600 fade q 0.001 0.08 0.07
sox -m $T/g1.wav $T/g2.wav $R $A/clang.wav reverb 30 gain -n -3
# A watertight door swinging open: its dogs coming off, a short metal creak.
sox -n $R $A/door_open.wav synth 0.7 sawtooth 140-110 lowpass 900 tremolo 22 70 fade q 0.05 0.7 0.3 gain -n -8
# A torpedo being hoisted into a tube (reload): chain rattle and rumble.
sox -n $R $T/r1.wav synth 0.03 whitenoise bandpass 2500 1200 fade q 0.001 0.03 0.025 pad 0 0.09
sox $T/r1.wav $R $T/r2.wav repeat 19
sox -n $R $T/r3.wav synth 2.4 brownnoise lowpass 300 gain -10
sox -m $T/r2.wav $T/r3.wav $R $A/reload.wav trim 0 2.4 fade q 0.05 2.4 0.4 gain -n -6
# A diesel turning over and catching.
sox -n $R $T/s1.wav synth 1.6 sawtooth 25-60 lowpass 260 tremolo 9 80 fade q 0.1 1.6 0.2
sox -n $R $T/s2.wav synth 0.6 brownnoise lowpass 400 fade q 0.01 0.6 0.4 gain -2
sox $T/s1.wav $T/s2.wav $R $A/diesel_start.wav gain -n -4
# A scrubber canister clanking into its seat.
sox -n $R $A/canister.wav synth 0.4 sine 880 sine 1320 sine 1990 fade q 0.001 0.4 0.38 gain -n -9
# Pencil on the chart.
sox -n $R $A/pencil.wav synth 0.25 pinknoise highpass 2500 tremolo 30 70 fade q 0.02 0.25 0.08 gain -n -18
# Boots on the steel deck plates (three variants): a soft heel, a gritty sole scuff and a
# faint high ring from the plate. No low thud or tone, so it doesn't read as a knock on a
# door (Blaney).
for i in 1 2 3; do
  sox -n $R $T/f1.wav synth 0.05 pinknoise highpass 400 lowpass 2200 fade q 0.003 0.05 0.045 gain -8
  sox -n $R $T/f2.wav synth 0.11 whitenoise gain -6 bandpass $((3200 + i * 500)) 2500 fade q 0.015 0.11 0.08 gain -12
  sox -n $R $T/f3.wav synth 0.3 sine $((1900 + i * 170)) sine $((2870 + i * 230)) fade q 0.002 0.3 0.29 gain -30
  sox -m $T/f1.wav $T/f2.wav $T/f3.wav $R $A/step_$i.wav gain -n -14
done
sox -n $R $T/f3.wav synth 0.3 sine 520 sine 780 fade q 0.001 0.3 0.29 gain -10
sox -n $R $T/f4.wav synth 0.05 brownnoise lowpass 800 fade q 0.001 0.05 0.04
sox -m $T/f3.wav $T/f4.wav $R $A/rung.wav gain -n -10
# Picking up or putting down a tool.
sox -n $R $T/p1.wav synth 0.25 sine 700 sine 1080 fade q 0.001 0.25 0.24 gain -10
sox -n $R $T/p2.wav synth 0.04 whitenoise bandpass 1500 800 fade q 0.001 0.04 0.035
sox -m $T/p1.wav $T/p2.wav $R $A/tool.wav gain -n -10
