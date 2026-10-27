"""Bounded command runner: read-only source mount, offline image, writable evidence."""
import os,pathlib,subprocess
class Runner:
 def __init__(self,root,out,image=None,native=False,timeout=1500):self.root=pathlib.Path(root).resolve();self.out=pathlib.Path(out).resolve();self.image=image;self.native=native;self.timeout=timeout;self.index=0
 def path(self,p):
  p=pathlib.Path(p).resolve()
  if p.is_relative_to(self.out):return str(p) if self.native else '/evidence/'+p.relative_to(self.out).as_posix()
  if p.is_relative_to(self.root):return str(p) if self.native else '/omicstat/'+p.relative_to(self.root).as_posix()
  raise ValueError('command path outside source/evidence roots')
 def run(self,argv,stage):
  if not isinstance(argv,list) or not argv or not all(isinstance(v,str) and '\0' not in v for v in argv):raise ValueError('commands require explicit argv')
  self.index+=1;log=self.out/'logs'/('%s-%03d.log'%(stage,self.index));log.parent.mkdir(parents=True,exist_ok=True)
  while log.exists():self.index+=1;log=self.out/'logs'/('%s-%03d.log'%(stage,self.index))
  env=dict(os.environ,OMICSTAT_WRITE_GOLDEN='',PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',OMICSTAT_RUN_ID='acceptance-canonical')
  cmd=argv
  if not self.native:
   if not self.image:raise ValueError('verified image ID is unavailable')
   extra=[]
   acceptance=self.root/'.omicstat-acceptance'
   if acceptance.is_symlink():
    target=acceptance.resolve(strict=True)
    if not target.is_dir():raise ValueError('acceptance layer symlink must name a directory')
    extra+=['-v',str(target)+':/omicstat/.omicstat-acceptance:ro']
   if (self.root/'.git').is_file():
    common=subprocess.check_output(['git','-C',str(self.root),'rev-parse','--path-format=absolute','--git-common-dir'],text=True).strip()
    if pathlib.Path(common).is_dir():extra+=['-v',common+':'+common+':ro']
   cmd=['docker','run','--rm','--network=none','--memory',os.environ.get('OMICSTAT_ACCEPTANCE_MEMORY','6g'),'--read-only','--tmpfs','/tmp','--user',str(os.getuid())+':'+str(os.getgid()),'-v',str(self.root)+':/omicstat:ro','-v',str(self.out)+':/evidence:rw','-w','/omicstat','-e','OMICSTAT_WRITE_GOLDEN=','-e','PYTHONDONTWRITEBYTECODE=1','-e','OMICSTAT_RUN_ID=acceptance-canonical','-e','PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin','-e','HOME=/tmp','-e','TMPDIR=/tmp','-e','OMP_NUM_THREADS=1','-e','OPENBLAS_NUM_THREADS=1']+extra+[self.image]+argv
  try:
   p=subprocess.run(cmd,cwd=self.root,env=env,stdin=subprocess.DEVNULL,capture_output=True,text=True,timeout=self.timeout)
   result={'argv':cmd,'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr,'timed_out':False,'ok':p.returncode==0}
  except subprocess.TimeoutExpired as e:result={'argv':cmd,'returncode':None,'stdout':str(e.stdout or ''),'stderr':str(e.stderr or ''),'timed_out':True,'ok':False}
  except OSError as e:result={'argv':cmd,'returncode':None,'stdout':'','stderr':str(e),'timed_out':False,'ok':False}
  log.write_text('ARGV '+repr(cmd)+'\nRETURN '+str(result['returncode'])+'\nSTDOUT\n'+result['stdout']+'\nSTDERR\n'+result['stderr'])
  result['log']=str(log.relative_to(self.out));return result
