"""Worked-example acceptance; computations exclusively through module entries."""
import sys,json,subprocess,re
from pathlib import Path
import numpy as np,pandas as pd,anndata as ad
ROOT=Path('/omicstat'); BASE=Path('/scratch/e2e'); BASE.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'skills/_shared/py'))
from ospy.display import category_palette
from ospy import handoff as H

def run(module,name,source,extra,raw=False):
 out=BASE/name
 if (out/'provenance/resolved_spec.json').exists():
  H.read_handoff(str(out),front_end_ecosystem='scverse')
  print('RESUME verified run',name,flush=True);return out
 args=['--input' if raw else '--from-run',str(source),'--outdir',str(out),'--species','human','--annotation','scBaseCount-2026-01-12-gene-symbols','--sample-col','srx','--counts-layer','X' if raw else 'counts','--seed','20260925']+list(map(str,extra))
 command=[sys.executable,str(ROOT/'skills'/module/'scripts'/('run_'+module.replace('-','_')+'.py')),*args]
 print('RUN',name,' '.join(command),flush=True)
 with (BASE/(name+'.log')).open('w') as log:
  p=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
 if p.returncode:raise RuntimeError(name+' failed: '+(BASE/(name+'.log')).read_text()[-4000:])
 return out
raw=Path('/scratch/reference/data/gp6_umap_input.h5ad')
qc_flags=['--mito-prefix','MT-','--min-genes',200,'--max-genes',10000,'--min-counts',500,'--max-counts',100000,'--max-mito-percent',20,'--min-cells',3,'--doublet-mode','skip']
cl_flags=['--n-hvg',2000,'--n-pcs',30,'--n-neighbors',30,'--resolution',1.0,'--target-sum',10000,'--min-dist',0.1]
vi_flags=['--batch-col','srx','--cluster-col','cluster','--max-epochs',100,'--n-neighbors',30,'--min-dist',0.1]
q=run('scanpy-qc','qc0',raw,qc_flags,True)
c=run('scanpy-cluster','cluster0',q,cl_flags)
features=BASE/'features.txt'
if not features.exists():
 df=pd.read_csv(c/'tables/variable_genes.csv'); features.write_text('\n'.join(df.loc[df.highly_variable.astype(str).str.lower()=='true','feature_id'])+'\n')
v=run('scvi-integrate','scvi0',c,vi_flags+['--features-file',features,'--leiden-resolution',1.0,'--scvi-cluster-col','scvi_cluster'])
m=run('scanpy-markers','markers0',v,['--cluster-col','scvi_cluster','--expression-layer','logcounts','--purpose','cluster-description','--test','wilcoxon','--n-genes',15,'--top-n',3])
ref=pd.read_csv('/scratch/reference/cluster_annotation.csv',dtype={'cluster':str})
panel={}
for _,row in ref.iterrows():
 if row.cell_type_ours=='Unresolved':continue
 genes=re.findall(r'\b[A-Z][A-Z0-9-]+\b',str(row.markers).split('(')[0])
 if row.cell_type_ours not in panel:panel[row.cell_type_ours]={'genes':[],'lineage':row.lineage_ours,'order':len(panel)}
 panel[row.cell_type_ours]['genes']=list(dict.fromkeys(panel[row.cell_type_ours]['genes']+genes))
# Reproduce the reference figure's type merging and lineage order from its table.
display=pd.read_csv('/scratch/reference/umap_annotation_balanced.csv')
merge=display[['cell_type_ours','display_type','lineage_ours','type_no']].drop_duplicates().set_index('cell_type_ours')
merged={}
for name,entry in panel.items():
 target=str(merge.loc[name,'display_type']) if name in merge.index else name
 if target not in merged:merged[target]={'genes':[],'lineage':entry['lineage'],'order':int(merge.loc[name,'type_no']) if name in merge.index else 100+entry['order']}
 merged[target]['genes']=list(dict.fromkeys(merged[target]['genes']+entry['genes']))
palette=category_palette()
for i,name in enumerate(sorted(merged,key=lambda n:merged[n]['order'])):
 if i>=len(palette):raise RuntimeError('unexpected reference palette size')
 merged[name]['colour']=palette[i]
panel_path=BASE/'marker_panel.json';panel_path.write_text(json.dumps(merged,indent=2)+'\n')
# Adapt coordinator manual annotations by cell membership, never source-study cell_type.
coordinator=pd.read_csv('/scratch/reference/umap_annotation.csv',dtype={'cluster':str}).set_index('cell')
current=ad.read_h5ad(v/'objects/adata.h5ad',backed='r')
rows=[]; label_map={}
for cluster,obs in current.obs.groupby('scvi_cluster',observed=True):
 evidence=coordinator.reindex(obs.index).cell_type_ours.fillna('Unresolved').value_counts()
 name=evidence.index[0]
 target=str(merge.loc[name,'display_type']) if name in merge.index else name
 label_map[str(cluster)]=target if target in merged else 'Unresolved'
 rows.append({'cluster':str(cluster),'name':label_map[str(cluster)],'coordinator_agreement':float(evidence.iloc[0]/len(obs)),'n':len(obs)})
pd.DataFrame(rows).to_csv(BASE/'label_map_evidence.csv',index=False)
map_path=BASE/'label_map.json';map_path.write_text(json.dumps(label_map,indent=2)+'\n')
a=run('scanpy-annotate','annotate0',m,['--cluster-col','scvi_cluster','--marker-panel',panel_path,'--label-map',map_path,'--unresolved-label','Unresolved','--expression-layer','logcounts','--display-max-per-group',200])
purity_flags=['--label-col','celltype','--graph-key','scvi_neighbors','--purity-threshold',0.6,'--embedding-neighbors',15,'--embedding-purity-threshold',0.6,'--island-eps',0.35,'--island-min-samples',5,'--island-min-size',10,'--exclude-label','Unresolved']
for round in (1,2):
 p=run('scanpy-purity','purity'+str(round),a,purity_flags)
 q=run('scanpy-qc','qc'+str(round),p,qc_flags+['--cell-list',p/'tables/retained_cells.csv'])
 c=run('scanpy-cluster','cluster'+str(round),q,cl_flags)
 round_features=BASE/('features_round'+str(round)+'.txt')
 if not round_features.exists():
  df=pd.read_csv(c/'tables/variable_genes.csv')
  round_features.write_text('\n'.join(df.loc[df.highly_variable.astype(str).str.lower()=='true','feature_id'])+'\n')
 a=run('scvi-integrate','scvi'+str(round),c,vi_flags+['--features-file',round_features])
# Final isolation pass before balanced reference map; no retraining on small set.
p=run('scanpy-purity','purity_final',a,purity_flags)
adata=ad.read_h5ad(a/'objects/adata.h5ad',backed='r'); kept=pd.read_csv(p/'tables/retained_cells.csv').cell
obs=adata.obs.loc[kept];rng=np.random.default_rng(20260925)
balanced=[]; fill=[]
for typ,frame in obs.groupby('celltype',observed=True,sort=True):
 ids=list(rng.permutation(frame.index))
 balanced+=ids[:200];fill+=ids[200:500]
for name,ids in [('balanced_cells',balanced),('fill_cells',fill)]:pd.DataFrame({'cell':ids}).to_csv(BASE/(name+'.csv'),index=False)
b=run('scvi-integrate','balanced',a,['--batch-col','srx','--cluster-col','cluster','--max-epochs',100,'--n-neighbors',30,'--latent-from-run',a,'--cell-list',BASE/'balanced_cells.csv','--min-dist',0.5,'--umap-spread',1.5])
registry=BASE/'colour_registry.json'; registry.write_text(json.dumps({'schema':'omicstat.colour-registry.v1','families':{'celltype':{n:e['colour'] for n,e in merged.items()}}},indent=2)+'\n')
refmap=ad.read_h5ad(b/'objects/adata.h5ad',backed='r'); span=np.ptp(refmap.obsm['X_umap'],axis=0).max();eps=float(span*0.025)
i=run('scanpy-ingest','ingest',a,['--query-run',a,'--reference-run',b,'--cell-list',BASE/'fill_cells.csv','--label-col','celltype','--neighbors-key','scvi_neighbors','--n-neighbors',30,'--colour-registry',registry,'--label-placement','largest-island','--label-island-eps',eps,'--label-island-min-samples',5,'--embedding-width','double','--embedding-height-mm',160])
print('E2E computational pipeline complete',i,flush=True)
