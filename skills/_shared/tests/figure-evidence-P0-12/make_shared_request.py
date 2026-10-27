"""Write a purely invented typed FigureRequest fixture for real R replay."""
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'py'))
from ospy.figure_request import FigureRequest,frame
from ospy.figure_semantics import definition,layer,statistic
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
d=dict(observation_id=['invented_obs'+str(i) for i in range(1,7)],person_id=['invented_person'+str(i) for i in [1,2,3,1,2,3]],visit=[1,1,1,2,2,2],seconds=[24000,25000,26000,20000,22000,23000],probability=[.2,.3,.4,.3,.4,.5])
pop=dict(status='known',ids=d['observation_id'],rule='all six artificial visits')
def make(column,quantity,unit):
    return definition(quantity,'visit','people',unit,pop,pop,'none',[layer(column,d,['observation_id'],'observed',quantity,unit,d['person_id'],'people',population_id='artificial_people',value_columns=[column])])
r=FigureRequest(str(out),'synthetic-semantics','0.0.0',journal=sys.argv[2] if len(sys.argv)>2 else 'nature')
for column,quantity,unit,title in [('seconds','runtime','seconds','Runtime (seconds)'),('probability','probability','fraction','Supplied probability')]:
    r.add(column,'os_diag_xy',{'df':frame(d)},args=dict(x='visit',y=column,kind='points',xlab='Visit',ylab=title),definition=make(column,quantity,unit),width='double',height_mm=90)
r.write()
(out/'SOURCE.json').write_text(json.dumps({'source':'artificial deterministic fixture; no real participants or paper pixels','data':d},indent=2)+'\n')
