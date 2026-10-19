# usage: python3 add_items.py <path to ox_inventory/data/items.lua> <path to items block>
import sys, shutil, time
dst, blk = sys.argv[1], sys.argv[2]
src = open(dst, encoding='utf-8').read()
if "['murko_taco']" in src:
    print('murko items already in items.lua - skipped'); sys.exit(0)
i = src.rstrip().rfind('}')
if i < 0:
    print('could not find closing } in items.lua'); sys.exit(1)
shutil.copy(dst, dst + '.bak_' + time.strftime('%Y%m%d%H%M%S'))
head = src[:i].rstrip()
if not head.endswith(','): head += ','
out = head + '\n\n' + open(blk, encoding='utf-8').read().rstrip() + '\n' + src[i:]
open(dst, 'w', encoding='utf-8').write(out)
print('added murko items to', dst)
