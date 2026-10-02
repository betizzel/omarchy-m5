#!/usr/bin/env python3
"""Tee the m1n1 hypervisor's virtual UART (/dev/m1n1-sec) to stdout and a log file."""
import sys, time, serial

dev = sys.argv[1] if len(sys.argv) > 1 else "/dev/m1n1-sec"
log = open(sys.argv[2] if len(sys.argv) > 2 else "vuart.log", "ab", buffering=0)
while True:
    try:
        s = serial.Serial(dev, 115200, timeout=0.2)
    except serial.SerialException:
        time.sleep(0.5)
        continue
    try:
        while True:
            d = s.read(4096)
            if d:
                log.write(d)
                sys.stdout.buffer.write(d)
                sys.stdout.flush()
    except serial.SerialException:
        time.sleep(0.5)
