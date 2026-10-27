"""Exact artificial matrix bridge contracts; standard library only."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ospy.errors import OmicstatError
from ospy.figure_request import FigureRequest, frame, matrix, validate_request, write_data_csv

class MatrixRequestTests(unittest.TestCase):
    def test_keyed_annotation_roundtrip(self):
        with tempfile.TemporaryDirectory() as out:
            request = FigureRequest(out, 'synthetic', '0')
            request.add('heat', 'os_heatmap', {'mat': matrix([[1/3, 0], [None, float('inf')]], ['r1', 'r2'], ['s1', 's2']),
                'col_annot': frame({'sample': ['s2', 's1'], 'condition': ['a', 'b']}, row_id='sample')}, args={'value_title': 'value'})
            path = request.write(); d = json.loads(Path(path).read_text())
            self.assertEqual(d['figures'][0]['data']['col_annot']['row_id_column'], 'sample')
            self.assertEqual(validate_request(out), [])
            csv = Path(out, 'figure_data/heat__mat.csv').read_text()
            self.assertIn('0.33333333333333331', csv); self.assertIn('NA,Inf', csv)
    def test_annotation_ids_required(self):
        for rows, key in (({'id':['a','a']},'id'), ({'id':['a',None]},'id'), ({'id':[1,2]},'id'), ({'id':['a','b']},'absent')):
            with self.subTest(rows=rows), self.assertRaises(OmicstatError): frame(rows,row_id=key)
    def test_matrix_ids_unique_nonempty(self):
        for rows, cols in ((['r','r'],['a','b']),(['','r'],['a','b']),(['r','s'],['a','a']),(['r','s'],['a',''])):
            with self.subTest(rows=rows,cols=cols), self.assertRaises(OmicstatError): matrix([[1,2],[3,4]],rows,cols)
    def test_matrix_shape(self):
        with self.assertRaises(OmicstatError): matrix([[1]],['r'],['a','b'])
    def test_numeric_integer_loss_refused(self):
        with tempfile.TemporaryDirectory() as out:
            for number in (2**53+1,-(2**53+1),2**2048):
                with self.subTest(number=number), self.assertRaises(OmicstatError):
                    write_data_csv(matrix([[number]],['r'],['c']),str(Path(out,'data.csv')))
    def test_large_exact_integer_supported(self):
        with tempfile.TemporaryDirectory() as out:
            d=frame({'id':['r'],'value':[2**54]})
            self.assertEqual(d['columns'][1]['type'],'numeric')
            path=write_data_csv(d,str(Path(out,'data.csv')))
            self.assertIn(str(2**54),Path(path).read_text())
    def test_explicit_r_integer_range(self):
        with tempfile.TemporaryDirectory() as out:
            for number in (2**31,-2**31,1.5):
                with self.subTest(number=number), self.assertRaises(OmicstatError):
                    write_data_csv(frame({'x':[number]},types={'x':'integer'}),str(Path(out,'data.csv')))
    def test_tampered_csv(self):
        with tempfile.TemporaryDirectory() as out:
            r=FigureRequest(out,'synthetic','0');r.add('h','os_heatmap',{'mat':matrix([[1]],['r'],['c'])});r.write()
            Path(out,'figure_data/h__mat.csv').write_text('tampered')
            self.assertIn('sha256 mismatch',validate_request(out)[0])

if __name__=='__main__': unittest.main()
