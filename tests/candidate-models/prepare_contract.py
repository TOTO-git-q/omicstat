"""Synthetic fixture declarations only; never inferred from a user's data."""
import pathlib,sys
root=pathlib.Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'mcp'))
from study_contract import build_contract,contract_bytes
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
contract=build_contract(design='Declared synthetic demonstration; module-specific fixture definitions recorded in source',biological_unit='Biological specimen or repeated subject as explicitly identified in fixture',population='Complete synthetic fixture; no data-derived exclusions',comparison=dict(target='Prespecified model contrast or inverse dose',measure='Original endpoint units or concentration',exposure='Declared condition or dose',comparator='Declared reference or curve baseline'),outcomes=[dict(name='Fixture endpoint',timepoint='Prespecified fixture observation')],covariates=[],missing_data='Module-specific missingness policy stated explicitly in CLI',multiplicity='Explicit module adjustment; exploratory synthetic fixture only',analysis_sets=['All rows passing documented input contract'],schema_path=root/'skills/_shared/schemas/study_contract.v1.schema.json')
(out/'contract.json').write_bytes(contract_bytes(contract))
