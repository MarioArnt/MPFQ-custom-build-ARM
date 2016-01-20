#!/bin/sh

case "`arch`" in
    i686)       w=32;;
    x86_64)     w=64;;
    *)  exit 1;;
esac

echo $w

