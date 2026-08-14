#!/bin/sh
# Generate the Xcode project.
#
# Sources the operator's credential file so a developer's DEVELOPMENT_TEAM —
# if they have set one — flows into device signing. The factory and CI run
# without one and build unsigned for simulators; the credential never enters
# the repository.
[ -f "$HOME/.powerplant/env" ] && . "$HOME/.powerplant/env"
export DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
exec xcodegen generate "$@"
