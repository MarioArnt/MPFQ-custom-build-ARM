#!/bin/sh

m=unknown

if grep -qi opteron /proc/cpuinfo ; then
    m=opteron
elif grep -qi 'Core(TM)2' /proc/cpuinfo ; then
    m=core2
fi


echo $m
