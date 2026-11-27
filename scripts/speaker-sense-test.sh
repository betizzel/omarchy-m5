#!/usr/bin/env bash
# speaker-sense-test.sh: check that speakerguardd v2 reads each amplifier's own V/I sense.
#
# The amplifiers send their voltage and current back as one interleaved capture with no frame
# marker. If that capture restarts mid-frame, every sense word moves to another amplifier and the
# protection models each speaker from someone else's speaker. The boot-time switch test can't see
# this, because the rotation happens later (kernels before v272-26 did it on every PipeWire restart).
#
# What it does, about 45 s, as the logged-in user, with speakerguardd v2 running:
#   - plays a faint 2.5 kHz tone (-34 dBFS, in the tweeters' band) on one side at a time through the
#     normal protected sink,
#   - records the protect stage's input from its monitor (speaker feed + sense words),
#   - finds which sense word carries the tone and compares it with the self-check's map
#     (/var/lib/speakerguardd/selfcheck.json): "shift 0" means the map holds,
#   - forces two restarts by stalling PipeWire for 150 ms during a 10 s tone,
#   - checks three fresh starts (the amps idle out first) and the right side,
#   - prints each amplifier's fault status.
# You hear a faint tone and two short stutters, so it asks first (`--yes` skips the question). Pause
# other audio first, or the fresh starts aren't fresh.
# Exit status: 0 when every steady stretch reads shift 0, 1 otherwise, 2 when it can't run.
# Needs: pipewire-utils (pw-play, pw-record), alsa-utils, python with numpy (uses `uv` for a cache
# venv if numpy is missing).
set -u

if [ "${1:-}" != "--yes" ]; then
  [ -t 0 ] || { echo "speaker-sense-test: plays a faint tone for about 45 s; run with --yes to confirm" >&2; exit 2; }
  read -r -p "This plays a faint 2.5 kHz tone through the speakers for about 45 s. Go ahead? [y/N] " ok
  [[ $ok == [yY]* ]] || exit 2
fi

die() { echo "speaker-sense-test: $*" >&2; exit 2; }

CONF=/etc/speakerguardd/speakerguardd.conf
SELF=/var/lib/speakerguardd/selfcheck.json
[ -r "$CONF" ] || die "no $CONF: speakerguardd v2 isn't provisioned on this Mac"
[ -r "$SELF" ] || die "no $SELF: the self-check hasn't passed yet"
systemctl is-active -q speakerguardd-v2 || die "speakerguardd-v2 isn't running"
# shellcheck disable=SC1090
. "$CONF"
MACHINE=${SGV2_MACHINE:?}
CARD=$(sed -nE 's/.*--card ([^ "]+).*/\1/p' <<<"${SGV2_ARGS:-}")
[ -n "$CARD" ] || die "no --card in SGV2_ARGS"
SINK="sgv2.voicing.$MACHINE"
TAP="alsa_output.platform-sound.RawSpeakers"
pw-cli info "$SINK" >/dev/null 2>&1 || die "no $SINK node: is the speaker graph loaded for this user?"

PY=python3
if ! python3 -c 'import numpy' 2>/dev/null; then
  VENV="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-m5/speaker-sense-venv"
  [ -x "$VENV/bin/python" ] || { command -v uv >/dev/null || die "needs numpy (python-numpy) or uv"
    uv venv -q "$VENV" && uv pip install -q -p "$VENV" numpy || die "couldn't set up numpy"; }
  PY="$VENV/bin/python"
fi

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; cd "$W" || exit 2
PW=$(pgrep -u "$(id -u)" -x pipewire | head -1)
[ -n "$PW" ] || die "no pipewire process for this user"
others=$(pw-link -l 2>/dev/null | awk -v s="$SINK:playback_" 'index($0, s) == 1 {in_s = 1; next}
          /^[^ ]/ {in_s = 0} in_s && /\|<-/ {split($2, a, ":"); print a[1]}' | sort -u | wc -l)
[ "$others" -gt 0 ] && echo "note: $others other stream(s) playing to $SINK; the fresh-start cases won't restart the amps"

# Channel map from the self-check: the tweeters' speaker slots and their V sense words.
read -r NSENSE LT_SLOT LT_V RT_SLOT RT_V < <("$PY" - "$SELF" <<'EOF'
import json, sys
w = json.load(open(sys.argv[1]))["wiring"]
tw = {a["side"]: a for a in w["amps"] if a["role"] == "tweeter"}
print(len(w["sense"]), tw["L"]["slot"], tw["L"]["v_ch"], tw["R"]["slot"], tw["R"]["v_ch"])
EOF
) || die "couldn't read the wiring from $SELF"
NAMP=$(( $("$PY" -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["wiring"]["amps"]))' "$SELF") ))
NCH=$((NAMP + NSENSE))

"$PY" - <<'EOF'
import numpy as np, wave
sr = 48000
def tone(path, side, secs):
    n = secs * sr; t = np.arange(n) / sr; x = np.sin(2 * np.pi * 2500 * t) * 10 ** (-34 / 20)
    k = 960; x[:k] *= np.linspace(0, 1, k); x[-k:] *= np.linspace(1, 0, k)
    st = np.zeros((n, 2)); st[:, 0 if side == 'L' else 1] = x
    w = wave.open(path, 'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes((st * 32767).astype('<i2').tobytes()); w.close()
tone('L10.wav', 'L', 10); tone('L2.wav', 'L', 2); tone('R2.wav', 'R', 2)
EOF

rec() { timeout "$2" pw-record --target "$TAP" -P '{ stream.capture.sink=true }' --rate 48000 \
          --channels "$NCH" --format s16 "$1" & }

echo "== forced restarts: 10 s tone, PipeWire stalled 150 ms at 3 s and 6.5 s"
rec run1.wav 12; REC=$!; sleep 0.5
pw-play --target "$SINK" L10.wav & PLAY=$!
sleep 3; kill -STOP "$PW"; sleep 0.15; kill -CONT "$PW"
sleep 3.5; kill -STOP "$PW"; sleep 0.15; kill -CONT "$PW"
wait "$PLAY"; wait "$REC"

echo "== fresh starts: 3 x (amps idle out, then left 2 s); then right 2 s"
for i in 1 2 3; do sleep 7; rec "fresh$i.wav" 3.5; REC=$!; sleep 0.5; pw-play --target "$SINK" L2.wav; wait "$REC"; done
sleep 7; rec right.wav 3.5; REC=$!; sleep 0.5; pw-play --target "$SINK" R2.wav; wait "$REC"

"$PY" - "$NAMP" "$NSENSE" "$LT_SLOT" "$LT_V" "$RT_SLOT" "$RT_V" <<'EOF'
import numpy as np, struct, sys
namp, nsense, lt_slot, lt_v, rt_slot, rt_v = map(int, sys.argv[1:])
nch = namp + nsense
def load(p):
    b = open(p, 'rb').read(); i = 12
    while i < len(b):
        cid = b[i:i+4]; sz = struct.unpack('<I', b[i+4:i+8])[0]
        if cid == b'data': d = b[i+8:]; break
        i += 8 + sz + (sz & 1)
    fb = 2 * nch
    return np.frombuffer(d[:len(d) // fb * fb], dtype='<i2').reshape(-1, nch).astype(float) / 32768
sr = 48000; n = 12000; f = 2500 * n // sr; win = np.hanning(n)[:, None]
def shifts(p, feed, own_v):
    a = load(p); wins = []
    for k in range(0, len(a) - n, n):
        wins.append((k, np.abs(np.fft.rfft(a[k:k+n] * win, axis=0))[f-2:f+3].max(0)))
    if not wins: return []
    # A muted or near-zero sink gives no tone to follow (the feed's silence floor is about -40 here).
    if max(20 * np.log10(S[feed] + 1e-9) for _, S in wins) < -10: return []
    # The feed level follows the user's volume: the tone windows are those within 6 dB of the loudest.
    top = max(20 * np.log10(S[feed] + 1e-9) for _, S in wins)
    out = []
    for k, S in wins:
        if 20 * np.log10(S[feed] + 1e-9) < top - 6: continue     # no tone in this window
        s = 20 * np.log10(S[namp:] + 1e-9)
        pair = s + np.roll(s, -1)                                 # V and I of one amp, any offset
        out.append(((own_v - int(np.argmax(pair))) % nsense, k / sr))
    return out
bad = 0
for p, feed, v, lab in [('run1.wav', lt_slot, lt_v, 'forced restarts'), ('fresh1.wav', lt_slot, lt_v, 'fresh start 1'),
                        ('fresh2.wav', lt_slot, lt_v, 'fresh start 2'), ('fresh3.wav', lt_slot, lt_v, 'fresh start 3'),
                        ('right.wav', rt_slot, rt_v, 'right side')]:
    runs = []
    for s, t in shifts(p, feed, v):
        if runs and runs[-1][0] == s: runs[-1][2] = t; runs[-1][3] += 1
        else: runs.append([s, t, t, 1])
    steady = [r for r in runs if r[3] >= 3]                       # windows across a restart can read anything
    ok = bool(steady) and all(r[0] == 0 for r in steady)
    bad += not ok
    print(f"{lab:16s} {'PASS' if ok else 'FAIL'}  steady shifts: " +
          (', '.join(f'{r[0]} ({r[1]:.2f}-{r[2]:.2f} s)' for r in steady) or 'no tone found'))
print('RESULT:', 'shift 0 everywhere' if not bad else f'{bad} case(s) with a non-zero shift')
sys.exit(1 if bad else 0)
EOF
rc=$?

echo "== amplifier fault status (0 expected)"
amixer -c "$CARD" scontents | awk '/Fault Status/{n=$0} /Front Left:/&&n{print n" -> "$0; n=""}' | sed "s/Simple mixer control //"
exit $rc
