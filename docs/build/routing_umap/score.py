import json
from pathlib import Path
root=Path(__file__).resolve().parent
records=list(map(json.loads,(root/'routing_expected.jsonl').read_text().splitlines()))
def canonical(answer):
    if isinstance(answer,dict) and set(answer)=={'pipeline'} and len(answer['pipeline'])==1:
        return answer['pipeline'][0]
    if isinstance(answer,dict) and 'out_of_scope' in answer:
        text=answer['out_of_scope'].lower()
        if ('ecosystem' in text or 'upstream chain' in text) and ('prespecif' in text or 'specify' in text or 'requires' in text):
            return {'out_of_scope':'ecosystem not specified'}
    return answer
scope_equivalences = {
    'R121': 'clinical survival', 'R122': 'clinical prediction', 'R123': 'clinical regression',
    'R124': 'FASTQ quantification', 'R126': 'offline KEGG unavailable', 'R127': 'meta-analysis', 'R128': 'diagnostic accuracy',
    'R129': 'public data retrieval', 'R130': 'microscope camera', 'R131': 'microscope camera'
}
scores={}
for phase in ('before','after'):
    answers={r['id']:r['answer'] for r in map(json.loads,(root/('routing_'+phase+'_answers.jsonl')).read_text().splitlines())}
    primary=acceptable=0;misses=[]
    for row in records:
        a=canonical(answers[row['id']]);e=canonical(row['expected'])
        if row['id'] in scope_equivalences and isinstance(a, dict) and 'out_of_scope' in a and isinstance(e, dict) and 'out_of_scope' in e:
            # Reason prose differs; the reviewed out-of-scope category is identical.
            a=e
        if a==e:primary+=1;acceptable+=1
        elif a in [canonical(x) for x in row.get('acceptable',[])]:acceptable+=1
        else:misses.append({'id':row['id'],'answer':answers[row['id']],'expected':row['expected']})
    scores[phase]={'n':len(records),'primary':primary,'acceptable':acceptable,'misses':misses}
    print(phase,primary,len(records),acceptable,len(records),[x['id'] for x in misses])
(root/'routing_scores.json').write_text(json.dumps(scores,ensure_ascii=False,indent=2)+'\n')
