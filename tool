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

#!/usr/bin/env python3
import pathlib, re, subprocess, sys
root = pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '.')
cpp = root/'libraries/AP_OSD/AP_OSD_Screen.cpp'
hpp = root/'libraries/AP_OSD/AP_OSD.h'
s, h = cpp.read_text(), hpp.read_text()
if 'ESC2TEMP' in s:
    raise SystemExit('Already patched; use a clean checkout')
# Work on both files in memory; fail closed if the source layout differs.
def once(text, old, new):
    if text.count(old)!=1:
        raise RuntimeError('Expected unique source anchor: '+old)
    return text.replace(old,new,1)
start=s.index('const AP_Param::GroupInfo AP_OSD_Screen::var_info2[]')
end=s.index('AP_GROUPEND',start)
block=s[start:end]
for idx in (11,12,13):
    if re.search(r'AP_(?:SUBGROUPINFO|GROUPINFO(?:_FLAGS)?)\([^\n]*,\s*'+str(idx)+r'\s*,',block):
        raise RuntimeError('Parameter index already occupied')
new = """
#if HAL_WITH_ESC_TELEM
    AP_GROUPINFO("ESC2_IDX", 11, AP_OSD_Screen, esc2_index, 10),
    AP_SUBGROUPINFO(esc2_temp, "ESC2TEMP", 12, AP_OSD_Screen, AP_OSD_Setting),
    AP_SUBGROUPINFO(esc2_rpm, "ESC2RPM", 13, AP_OSD_Screen, AP_OSD_Setting),
#endif

    """
s=s[:end]+new+s[end:]
for kind in ('temp','rpm'):
    name='draw_esc_'+kind
    m=re.search(r'void\s+AP_OSD_Screen::'+name+r'\s*\([^)]*\)\s*\{',s)
    if not m: raise RuntimeError('Missing renderer '+name)
    depth=1; pos=m.end()
    while depth:
        if s[pos]=='{': depth+=1
        elif s[pos]=='}': depth-=1
        pos+=1
    original=s[m.start():pos]
    if 'esc_index' not in original: raise RuntimeError('Unexpected renderer')
    clone=original.replace(name,'draw_esc2_'+kind).replace('esc_index','esc2_index')
    s=s[:pos]+'\n\n'+clone+s[pos:]
    decl=re.search(r'void\s+'+name+r'\s*\([^;]*\);',h)
    if not decl: raise RuntimeError('Missing declaration')
    h=h[:decl.end()]+'\n    '+decl.group().replace(name,'draw_esc2_'+kind)+h[decl.end():]
    field=re.search(r'AP_OSD_Setting\s+esc_'+kind+r'\s*[^;]*;',h)
    if not field: raise RuntimeError('Missing setting')
    h=h[:field.end()]+'\n    '+field.group().replace('esc_'+kind,'esc2_'+kind)+h[field.end():]
    # Reuse the stock drawing macro in the same conditional compilation scope.
    call=re.search(r'^[ \t]*DRAW_ITEM\(\s*esc_'+kind+r'\s*\);',s,re.M)
    if not call: raise RuntimeError('Missing DRAW_ITEM call')
    s=s[:call.end()]+'\n'+call.group().replace('esc_'+kind,'esc2_'+kind)+s[call.end():]
m=re.search(r'AP_Int8\s+esc_index\s*[^;]*;',h)
if not m: raise RuntimeError('Missing ESC index declaration')
h=h[:m.end()]+'\n    AP_Int8 esc2_index;'+h[m.end():]
cpp.write_text(s); hpp.write_text(h)
print('Patched: ESC2_IDX / ESC2TEMP / ESC2RPM. Compilation still required.')
