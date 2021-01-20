#!/bin/sh

set -o errexit

if ! [ -x "$(command -v brctl)" ]; then
  >&2 echo '`brctl` could not be found; please double check that the package is installed.'
  exit 1
fi

brctl addif virbr0 $1
ifconfig $1 up
