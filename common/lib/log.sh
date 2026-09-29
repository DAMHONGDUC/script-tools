#!/usr/bin/env bash
# Timestamped, coloured log lines for every script. Source this file.
#
# Every line is three columns — time, a three-wide gutter holding the mark, then
# the message — so times and messages each read down one column:
#
#   [10:04:31]: ==> config — dev                  a step, flush left
#   [10:04:31]:   i installing 6 files            a line inside that step
#   [10:04:31]:   · env_assets/dev.json -> env/…  an entry in a list under it
#   [10:04:32]: ✔   dev config installed          the script's own verdict
#
# One meaning per colour: cyan opens a step, blue informs, yellow warns, green
# passed, red failed, magenta waits for an answer. The mark carries the colour
# and the message stays plain, so a ✘ is found rather than read for.

# Colour on unless NO_COLOR (no-color.org) says otherwise.
if [ -z "${NO_COLOR:-}" ]; then
  C_STEP=$(printf '\033[1;36m')
  C_INFO=$(printf '\033[1;34m')
  C_WARN=$(printf '\033[1;33m')
  C_OK=$(printf '\033[1;32m')
  C_BAD=$(printf '\033[1;31m')
  C_ASK=$(printf '\033[1;35m')
  C_TIME=$(printf '\033[1;37m')
  C_DIM=$(printf '\033[2m')
  C_OFF=$(printf '\033[0m')
else
  C_STEP='' C_INFO='' C_WARN='' C_OK='' C_BAD='' C_ASK='' C_TIME='' C_DIM='' C_OFF=''
fi

# Exported because `git submodule foreach` runs its body in a shell of its own:
# the environment crosses over, the functions below do not.
export C_STEP C_INFO C_WARN C_OK C_BAD C_ASK C_TIME C_DIM C_OFF

_stamp() { printf '%s[%s]:%s' "$C_TIME" "$(date '+%H:%M:%S')" "$C_OFF"; }

# $1 gutter (three columns, mark included), $2 its colour, $3 the message.
_line() { printf '%s %s%s%s %s\n' "$(_stamp)" "$2" "$1" "$C_OFF" "$3"; }

step() { printf '%s %s==> %s%s\n' "$(_stamp)" "$C_STEP" "$1" "$C_OFF"; }
info() { _line '  i' "$C_INFO" "$1"; }
warn() { _line '  ⚠' "$C_WARN" "$1"; }
ok() { _line '  ✔' "$C_OK" "$1"; }
bad() { _line '  ✘' "$C_BAD" "$1"; }
# Dim on purpose: six copied paths are one fact, and six blue marks claim six.
item() { _line '  ·' "$C_DIM" "$1"; }
done_msg() { _line '✔  ' "$C_OK" "$1"; }
# No newline: the answer is typed on the line the question is asked on.
ask() { printf '%s %s  ?%s %s' "$(_stamp)" "$C_ASK" "$C_OFF" "$1"; }
fail() {
  _line '✘  ' "$C_BAD" "$1" >&2
  exit 1
}

# Pads $1 out to $2 columns, so the second column of a list lines up.
pad() {
  local text="$1"
  while [ "${#text}" -lt "$2" ]; do
    text="$text "
  done
  printf '%s' "$text"
}
