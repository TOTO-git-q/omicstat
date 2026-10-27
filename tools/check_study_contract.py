#!/usr/bin/env python3
"""Strict engine-side StudyContract validator. No data or hash is inferred."""
import argparse,json,pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'skills/_shared/py'))
from ospy.study_contract import read_study_contract
from ospy.errors import OmicstatError
p=argparse.ArgumentParser();p.add_argument('path');p.add_argument('--expected-sha256');p.add_argument('--upstream');a=p.parse_args()
try:
 upstream=json.loads(pathlib.Path(a.upstream).read_text()) if a.upstream else None
 result=read_study_contract(a.path,upstream,a.expected_sha256);print(json.dumps({'path':result['path'],'sha256':result['sha256']}))
except (OmicstatError,ValueError,OSError) as e:print(str(e),file=sys.stderr);raise SystemExit(1)
