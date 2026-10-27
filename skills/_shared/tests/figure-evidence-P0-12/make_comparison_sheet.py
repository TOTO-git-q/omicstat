"""Join two unchanged synthetic figure renders into a labelled review sheet.

Requires Pillow only for developer artifact preparation; never used by a renderer.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

p=argparse.ArgumentParser()
p.add_argument('before');p.add_argument('after');p.add_argument('output')
p.add_argument('--item',required=True);p.add_argument('--preset',required=True)
p.add_argument('--figure',required=True)
p.add_argument('--font',default='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
a=p.parse_args()
sheet=Image.new('RGB',(2000,560),'white');draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype(a.font,20)
for k,(stage,path) in enumerate((('before',a.before),('after',a.after))):
    im=Image.open(path).convert('RGB');im.thumbnail((990,510))
    sheet.paste(im,(k*1000,45))
    draw.text((k*1000+10,8),f'{a.item} | {a.preset} | {stage} | {a.figure} | identical input/size',fill='black',font=font)
Path(a.output).parent.mkdir(parents=True,exist_ok=True)
sheet.save(a.output)
