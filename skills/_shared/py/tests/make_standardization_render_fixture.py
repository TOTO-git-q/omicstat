"""Data-only Python request for every P0-5 R builder (no plotting packages)."""
import pathlib, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from ospy.figure_request import FigureRequest, frame

def make(out):
    r=FigureRequest(out,module="omicstat-figure-test",module_version="0.1.0",journal="nature")
    r.add("km","os_km",data={"curves":frame([dict(time=t,survival=s,group="A") for t,s in [(0,1.),(1,.8),(2,.7)]]),
          "risk":frame([dict(time=t,n_risk=n,group="A") for t,n in [(0,10),(1,8),(2,6)]])},args={"time_unit":"months","logrank_p":.2})
    r.add("hr","os_hr_forest",data={"d":frame([dict(term="A",estimate=1.5,ci_low=1.1,ci_high=2.)])},args={"ci_level":.95})
    r.add("roc","os_time_roc",data={"d":frame([dict(fpr=x,tpr=y,horizon="12") for x,y in [(0.,0.),(.2,.7),(1.,1.)]])},args={"time_unit":"months"})
    r.add("lasso","os_lasso_path",data={"d":frame([{"lambda":x,"coefficient":y,"feature":"A"} for x,y in [(.01,.7),(.1,.4),(1.,0.)]])},args={"selected_lambda":.1})
    r.add("calibration","os_calibration",data={"d":frame([dict(predicted=x,observed=y) for x,y in [(.2,.3),(.7,.6)]])},args={"horizon":12,"time_unit":"months"})
    r.add("group","os_group_points",data={"d":frame([dict(group=g,value=v,unit=u) for g,v,u in [("A",1.,"a"),("A",1.2,"b"),("B",2.,"c"),("B",2.1,"d")]])},args={"unit_col":"unit","ylab":"Response"})
    r.add("standard","os_standard_curve",data={"obs":frame([dict(dose=x,response=y) for x,y in [(1.,.1),(10.,.6),(100.,.9)]]),
          "grid":frame([dict(dose=x,predicted=y) for x,y in [(1.,.1),(10.,.6),(100.,.9)]])},args={"unit":"ng/mL","model":"4PL","lloq":2,"uloq":80})
    r.write()
if __name__=="__main__":make(sys.argv[1])
