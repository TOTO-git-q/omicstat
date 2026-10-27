import pathlib,runpy,sys
root=pathlib.Path(__file__).resolve().parents[3]
sys.argv=[str(root/'tests/candidate-models/prepare.py'),'lme4-lmm',*sys.argv[1:]]
runpy.run_path(sys.argv[0],run_name='__main__')
