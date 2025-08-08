#!/usr/bin/env nu

# Test script to verify Nu functions work
print "Testing Nu shell functions..."
print ""

print "Available custom commands:"
help commands | where name =~ "sys-|gs|ga|gc|gp|projects|configs|sysinfo|dps|dclean|psg|knd|ad|ku|stam|nx-run|nx-runa|kc"

print ""
print "Testing sys-update command:"
sys-update