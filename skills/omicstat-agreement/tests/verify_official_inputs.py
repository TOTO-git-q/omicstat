"""Verify externally supplied original anchors without copying or printing rows."""
import argparse,csv,hashlib,io,json,pathlib,re

def verify(folder,descriptor=None):
    descriptor=descriptor or pathlib.Path(__file__).with_name('official_anchor_inputs.json')
    expected=json.loads(descriptor.read_text());folder=pathlib.Path(folder)
    if not folder.is_dir():raise ValueError('OS_MISSING_FILE: external official anchor folder is absent')
    receipt_path=folder/'SOURCE.json'
    if receipt_path.is_symlink() or not receipt_path.is_file():raise ValueError('OS_MISSING_FILE: external source receipt required')
    receipt=json.loads(receipt_path.read_text())
    if receipt.get('original_source_commit')!=expected['source_commit']:
        raise ValueError('OS_INVALID_INPUT: external source receipt must bind the original source commit')
    sources=receipt.get('sources',{})
    result={}
    for row in expected['datasets']:
        if row['file']!=pathlib.PurePosixPath(row['file']).name:raise ValueError('unsafe expected filename')
        p=folder/row['file'];s=sources.get(row['id'],{})
        if p.is_symlink() or not p.is_file():raise ValueError('OS_MISSING_FILE: an original anchor input is missing or unsafe')
        if p.stat().st_size>1024*1024:raise ValueError('OS_RESOURCE_LIMIT: unexpected anchor file size')
        raw=p.read_bytes()
        if not all(isinstance(s.get(k),str) and s[k].strip() for k in ['source_reference','checked_by','checked_at']):
            raise ValueError('OS_INVALID_INPUT: original source attribution and executor check are required')
        actual_sha=hashlib.sha256(raw).hexdigest()
        if s.get('file_sha256')!=actual_sha:raise ValueError('OS_INVALID_INPUT: external receipt byte hash differs')
        parsed=list(csv.reader(io.StringIO(raw.decode('utf-8'))))
        if not parsed or parsed[0]!=row['columns'] or len(parsed)-1!=row['rows']:
            raise ValueError('OS_INVALID_INPUT: exact original columns and row count required')
        rows=[]
        for values in parsed[1:]:
            if len(values)!=len(row['columns']):raise ValueError('OS_INVALID_INPUT: malformed original input')
            out=[]
            for k,v in zip(row['columns'],values):
                if k in row['integer_columns']:
                    if not re.fullmatch(r'-?(0|[1-9][0-9]*)',v):raise ValueError('OS_INVALID_INPUT: exact integer anchor value required')
                    out.append(int(v))
                else:out.append(v)
            rows.append(out)
        normalized=json.dumps({'columns':row['columns'],'rows':rows},separators=(',',':'),ensure_ascii=True).encode()
        if hashlib.sha256(normalized).hexdigest()!=row['normalized_sha256']:
            raise ValueError('OS_INVALID_INPUT: actual supplied values differ from the pinned original anchor')
        result[row['id']]={'file_sha256':actual_sha,'normalized_sha256':row['normalized_sha256'],'rows':row['rows'],
            'source_reference':s['source_reference'],'source_check_is_executor_declaration':True}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',required=True);p.add_argument('--receipt');a=p.parse_args()
    r=verify(a.source)
    if a.receipt:pathlib.Path(a.receipt).write_text(json.dumps(r,indent=2)+'\n')
    print('Three external original-case inputs match pinned expected values; no rows copied or printed; native execution remains separate.')
