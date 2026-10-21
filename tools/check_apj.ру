import json,base64,zlib,sys
p=json.load(open(sys.argv[1]))
b=zlib.decompress(base64.b64decode(p['image']))
assert p['board_id']==9, 'Wrong board ID'
assert p['summary']=='Pixhawk1-1M-bdshot', 'Wrong target'
assert len(b)==p['image_size']
assert len(b)<=p['image_maxsize'], 'Image too large'
assert b'ArduRover V4.7.2' in b, 'Wrong version'
for name in (b'ESC2_IDX', b'ESC2TEMP', b'ESC2RPM'):
    assert name in b, 'Missing custom OSD field: '+str(name)
print('APJ structure, target, version, size and custom parameter strings OK')
