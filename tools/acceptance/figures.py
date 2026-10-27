"""Figure metadata checks; owner sheets require verified registered real inputs."""
import io,pathlib
from .common import load,sha

def inspect_figures(run):
 run=pathlib.Path(run);records=[]
 for p in sorted((run/'figures').glob('*.png')):
  spec=p.with_suffix('.figure_spec.json');problems=[];s={}
  if p.is_symlink() or spec.is_symlink() or not p.resolve().is_relative_to(run.resolve()):raise ValueError('figure/spec path escapes run')
  if not spec.is_file():problems.append('missing figure spec')
  else:
   s=load(spec)
   if s.get('schema')!='omicstat.figure-spec.v1':problems.append('unknown figure spec schema')
   if not s.get('caption'):problems.append('missing caption')
   if not all(isinstance(s.get(k),(int,float)) and s[k]>0 for k in ['width_mm','height_mm','png_dpi']):problems.append('invalid dimensions/DPI')
   png=s.get('files',{}).get('png',{})
   if png.get('sha256')!=sha(p):problems.append('PNG SHA differs from spec')
   # Actual os_finalize_figure emits lint=[], distinct from absent lint evidence.
   lint=s.get('lint')
   if not isinstance(lint,list):problems.append('actual plot lint result absent; use os_finalize_figure')
   elif any(x.get('severity')=='blocker' for x in lint):problems.append('plot lint blocker')
  records.append({'path':p.relative_to(run).as_posix(),'sha256':sha(p),'spec':spec.relative_to(run).as_posix(),'lint':{'ok':not problems,'problems':problems,'plot_findings':s.get('lint')},'evidence_refs':s.get('evidence_refs',[]),'evidence_status':'present' if s.get('evidence_refs') else 'pending'})
 return records

def contact_sheet(run,records,destination,max_bytes=2*1024*1024,*,purpose='owner',owner_context=None):
 from PIL import Image,ImageDraw,ImageOps
 if not records:raise ValueError('No figures for contact sheet')
 if purpose not in ('owner','contract'):raise ValueError('explicit owner or contract sheet purpose required')
 if len(records)>128:raise ValueError('Split inventories larger than 128 figures before review')
 from .owner_data import _file
 for record in records:_file(run,record['path'])
 dataset=None
 if purpose=='owner':
  if not isinstance(owner_context,dict):raise ValueError('Owner sheet requires registered real-data evidence; synthetic contract figures are ineligible')
  from .owner_data import verify_run
  dataset=verify_run(run=run,records=records,**owner_context)
 destination=pathlib.Path(destination);destination.parent.mkdir(parents=True,exist_ok=True)
 width=420;columns=min(3,len(records));height=350
 def wrapped(draw,text,max_width):
  lines=['']
  for word in text.split():
   proposal=(lines[-1]+' '+word).strip()
   if draw.textbbox((0,0),proposal)[2]>max_width and lines[-1]:lines.append(word)
   else:lines[-1]=proposal
  return lines
 while width>=180:
  rows=(len(records)+columns-1)//columns;sheet=Image.new('RGB',(columns*width,rows*height),'white');draw=ImageDraw.Draw(sheet)
  for i,r in enumerate(records):
   label=('Dataset: '+dataset['label']+' ['+dataset['id']+']') if dataset else 'CONTRACT DIAGNOSTIC ONLY; not owner review'
   lines=wrapped(draw,label,width-12)+wrapped(draw,pathlib.Path(r['path']).name,width-12)
   header=8+14*len(lines)
   if header>height//2:raise ValueError('Dataset label too long; split/relabel registered review inventory')
   with Image.open(pathlib.Path(run)/r['path']) as im:
    im.load();thumb=ImageOps.contain(im.convert('RGB'),(width-12,height-header-10))
   x=(i%columns)*width;y=(i//columns)*height
   sheet.paste(thumb,(x+(width-thumb.width)//2,y+header+(height-header-10-thumb.height)//2))
   for j,line in enumerate(lines):draw.text((x+6,y+4+14*j),line,fill='black')
  data=io.BytesIO();sheet.save(data,format='PNG',optimize=True)
  if len(data.getvalue())<=max_bytes:
   destination.write_bytes(data.getvalue())
   return {'path':str(destination),'sha256':sha(destination),'bytes':destination.stat().st_size,'visual_review':None,
           'purpose':purpose,'owner_review_eligible':purpose=='owner',
           'dataset':None if dataset is None else {'id':dataset['id'],'label':dataset['label']},
           'figure_datasets':{r['path']:dataset['id'] for r in records} if dataset else {},
           'dataset_label_on_each_tile':dataset is not None}
  width=int(width*.8);height=int(height*.8)
 raise ValueError('Contact sheet exceeds 2 MiB; split figure inventory for review')
