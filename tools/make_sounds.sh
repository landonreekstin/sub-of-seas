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
# Loops (whole cycles): diesel chug, electric motor whine, water spraying, fire, torch hiss.
sox -n $R $A/diesel_loop.wav synth 2.0 brownnoise lowpass 220 tremolo 12 70 gain -n -6
sox -n $R $A/motor_loop.wav synth 2.0 sine 120 sine 240 sine 360 gain -n -12
sox -n $R $A/water_loop.wav synth 2.0 whitenoise gain -6 highpass 900 lowpass 6000 tremolo 7 20 gain -n -10
sox -n $R $A/fire_loop.wav synth 2.0 brownnoise lowpass 900 tremolo 17 80 gain -n -8
sox -n $R $A/torch_loop.wav synth 2.0 whitenoise gain -6 highpass 2500 gain -n -14
