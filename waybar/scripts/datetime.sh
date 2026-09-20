#!/bin/bash
day=$(date +%-d)
case $day in
    1|21|31) suffix="st" ;;
    2|22) suffix="nd" ;;
    3|23) suffix="rd" ;;
    *) suffix="th" ;;
esac
echo "$(date +%H:%M) - $(date +%a) ${day}${suffix} $(date +%B)"
