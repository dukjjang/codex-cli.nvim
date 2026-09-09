"""A real PTY peer: report literal input bytes without invoking a model."""
import os
import json
import sys
import tty

tty.setraw(0)
os.write(1, b'READY\r\n')
for argument in sys.argv[1:]:
    if argument.startswith('developer_instructions='):
        os.write(1, ('INSTRUCTIONS:' + json.loads(argument.split('=', 1)[1]).splitlines()[-1] + '\r\n').encode())
while True:
    data = os.read(0, 1024)
    if not data:
        break
    os.write(1, b'KEYS:' + data.hex().encode() + b'\r\n')
