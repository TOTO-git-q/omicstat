import csv,pathlib,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
with (out/'rank.csv').open('w',newline='') as f:
 w=csv.writer(f);w.writerow(['feature_id','symbol','score']);w.writerows([['1','A',2],['2','B',1]])
