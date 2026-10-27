"""Independent exact combinatorial hypergeometric and BH oracle, not engine output as truth."""
import csv,json,math,pathlib,sys
out=pathlib.Path(sys.argv[2]);rows=list(csv.DictReader((out/'tables/enrichment_table.csv').open()));mapping=list(csv.DictReader((out/'tables/input_mapping.csv').open()));pairs=list(csv.DictReader((out/'tables/effective_memberships.csv').open()))
u={x['gene_id'] for x in mapping if x['annotated']=='TRUE'};q={x['gene_id'] for x in mapping if x['selected']=='TRUE' and x['annotated']=='TRUE'};sets={}
for x in pairs:sets.setdefault(x['term_id'],set()).add(x['gene_id'])
N=len(u);n=len(q);den=math.comb(N,n);ps=[];count_error=[]
for x in rows:
 s=sets[x['term_id']]&u;k=len(s&q);M=len(s)
 p=sum(math.comb(M,j)*math.comb(N-M,n-j) for j in range(k,min(M,n)+1) if 0<=n-j<=N-M)/den
 ps.append(p);count_error.extend([abs(k-int(x['n_genes'])),abs(M-int(x['set_size'])),abs(n-int(x['n_effective_input'])),abs(N-int(x['n_effective_background']))])
order=sorted(range(len(ps)),key=ps.__getitem__);bh=[0.]*len(ps);last=1.
for rank in range(len(ps),0,-1):i=order[rank-1];last=min(last,ps[i]*len(ps)/rank);bh[i]=last
result={'exact_hypergeometric_max_error':max(abs(p-float(x['pvalue'])) for p,x in zip(ps,rows)),'independent_bh_max_error':max(abs(p-float(x['padj'])) for p,x in zip(bh,rows)),'integer_count_max_error':max(count_error),'author_selected_input_count':sum(x['selected']=='TRUE' for x in mapping)}
pathlib.Path(sys.argv[1]).write_text(json.dumps(result,indent=2)+'\n')
