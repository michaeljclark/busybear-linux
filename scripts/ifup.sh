#!/bin/sh

set -o errexit

brctl addif virbr0 $1
ifconfig $1 up
