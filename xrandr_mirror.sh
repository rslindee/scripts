#!/bin/bash

# TODO do I need the ?[1-9] for this, as well?
# get all connected outputs but not primary
connectedOutputs=$(xrandr | grep -E " connected (?!primary)" | sed -e "s/\([A-Z0-9]\+\) connected.*/\1/")
# Get active primary output
activeOutput=$(xrandr | grep -E " connected primary ?[1-9]+" | sed -e "s/\([A-Z0-9]\+\) connected.*/\1/")

# initialize variables
execute="xrandr "

for display in $connectedOutputs
do
	execute=$execute"--output $display --same-as $activeOutput "
done

# check if the default setup needs to be executed then run it
echo "Resulting Configuration:"
echo "Command: $execute"
$(execute)
# TODO What does this do?
echo -e "\n$(xrandr)"
