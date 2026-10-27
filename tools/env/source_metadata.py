"""Offline source metadata and additive-compatibility checks, never a resolver.

Index metadata can bind a published archive digest without attesting cached bytes,
a dependency closure, native imports, or an image build. Those remain distinct gates.
"""
from __future__ import annotations
import csv
import datetime as dt
import hashlib
import json
import pathlib
import re
from urllib.parse import unquote, urlsplit
from common import norm, safe_rel

SHA = re.compile(r'[0-9a-f]{64}')

def digest(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()

def local(root, relative):
    root = pathlib.Path(root).resolve()
    path = (root / safe_rel(relative)).resolve()
    if not path.is_relative_to(root):
        raise ValueError('source metadata path escapes repository')
    return path

def bound_json(root, binding):
    if not isinstance(binding, dict) or not SHA.fullmatch(str(binding.get('sha256', ''))):
        raise ValueError('source metadata requires an exact SHA256')
    path = local(root, binding['path'])
    if digest(path) != binding['sha256']:
        raise ValueError('source metadata SHA mismatch: ' + binding['path'])
    return json.loads(path.read_text())

def timestamp(value):
    result = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('artifact timestamp requires timezone')
    return result

def official_url(url, host, filename=None):
    parsed = urlsplit(url)
    if parsed.scheme != 'https' or parsed.netloc != host or parsed.query or parsed.fragment:
        raise ValueError('exact official HTTPS source without credentials/query required')
    if filename is not None:
        if pathlib.PurePosixPath(filename).name != filename or '\\' in filename:
            raise ValueError('flat artifact filename required')
        if unquote(parsed.path.rsplit('/', 1)[-1]) != filename:
            raise ValueError('artifact URL and filename disagree')
    return parsed

def matching_pair(value, name, version):
    if isinstance(value, dict):
        return any((key == name and item == version) or matching_pair(item, name, version)
                   for key, item in value.items())
    if isinstance(value, list):
        return any(matching_pair(item, name, version) for item in value)
    return False

def checked_official_record(root, row, cutoff):
    """Validate filtered official release metadata against one exact wheel tuple."""
    metadata = bound_json(root, row['metadata'])
    if metadata.get('metadata_only') is not True:
        raise ValueError('expected official metadata-only observation')
    if norm(metadata['package']) != norm(row['package']) or metadata['version'] != row['version']:
        raise ValueError('official metadata package/version mismatch')
    parsed = official_url(metadata['source_url'], 'pypi.org')
    if parsed.path != '/pypi/' + row['package'] + '/' + row['version'] + '/json':
        raise ValueError('official metadata URL does not identify pinned release')
    if not SHA.fullmatch(str(metadata.get('response_sha256', ''))):
        raise ValueError('official response observation digest missing')
    if metadata.get('yanked') is not False:
        raise ValueError('yanked or unknown release status')
    artifact = row['artifact']
    if artifact.get('kind') != 'wheel':
        raise ValueError('Python direct metadata must select a wheel')
    official_url(artifact['url'], 'files.pythonhosted.org', artifact['filename'])
    if not SHA.fullmatch(str(artifact.get('sha256', ''))):
        raise ValueError('artifact SHA256 missing')
    matches = [x for x in metadata['files'] if x['filename'] == artifact['filename']]
    if len(matches) != 1:
        raise ValueError('exact artifact absent or duplicated in official metadata')
    item = matches[0]
    expected = {'filename': item['filename'], 'url': item['url'],
                'sha256': item['digests']['sha256'], 'uploaded_utc': item['upload_time_iso_8601'],
                'yanked': item['yanked'], 'bytes': item['size'], 'kind': 'wheel'}
    if artifact != expected or item['packagetype'] != 'bdist_wheel' or item['yanked'] is not False:
        raise ValueError('artifact tuple differs from official metadata')
    if timestamp(artifact['uploaded_utc']) >= timestamp(cutoff):
        raise ValueError('artifact uploaded at or after fixed cutoff')
    from packaging.utils import parse_wheel_filename
    name, version, _, tags = parse_wheel_filename(artifact['filename'])
    if norm(name) != norm(row['package']) or str(version) != row['version']:
        raise ValueError('wheel filename identity differs from pinned package')
    # All direct choices reviewed in this revision are pure Python. Compiled
    # artifacts need a separate exact target-tag review, never this exception.
    if {str(t) for t in tags} != {'py3-none-any'}:
        raise ValueError('direct wheel is not the reviewed pure-Python target')
    return metadata

def inspect_metadata(candidate, manifest, root):
    binding = manifest.get('source_metadata')
    if binding is None:
        return None
    data = bound_json(root, binding)
    if data.get('schema') != 'omicstat.candidate-source-metadata.v1':
        raise ValueError('unsupported candidate source metadata schema')
    if data.get('candidate_id') != manifest['id'] or data.get('lane') != manifest['lane']:
        raise ValueError('source metadata candidate identity mismatch')
    if data.get('requested_packages') != manifest['new_packages']:
        raise ValueError('source metadata requested-package coverage differs from manifest')
    if data.get('parent_image') != {'tag': manifest['base_image'], 'id': manifest['base_image_id']}:
        raise ValueError('source metadata parent image binding mismatch')
    if data.get('artifact_bytes_verified_in_this_revision') is not False or data.get('native_verified_in_this_revision') is not False:
        raise ValueError('metadata cannot assert archive-byte or native verification')
    if data.get('closure_state') != 'incomplete':
        raise ValueError('this metadata review cannot attest a complete closure')
    inventory = data['lineage_baseline']
    if not SHA.fullmatch(inventory['sha256']) or digest(local(root, inventory['path'])) != inventory['sha256']:
        raise ValueError('lineage inventory SHA mismatch')
    records = data['packages']; seen = set(); requested = set(); observations = {}
    for row in records:
        if row.get('scope') not in ('requested','required_dependency','inherited'):
            raise ValueError('unrecognized source metadata package scope')
        key = norm(row['package']) if manifest['lane'] == 'py' else row['package']
        if key in seen:
            raise ValueError('duplicate source metadata package')
        seen.add(key)
        if row['scope'] == 'requested': requested.add(row['package'])
        if row.get('version') is not None:
            evidence = row.get('version_evidence')
            if not evidence:
                raise ValueError('exact version lacks source evidence')
            observed = bound_json(root, evidence)
            if evidence['kind'] == 'module_calls_registry':
                b = local(root, evidence['path']).read_bytes()
                git_blob = hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()
                if git_blob != evidence.get('git_blob') or not matching_pair(observed, row['package'], row['version']):
                    raise ValueError('module version evidence mismatch')
            elif evidence['kind'] != 'official_version_metadata':
                raise ValueError('unrecognized version evidence')
        if manifest['lane'] == 'py':
            implementation = row['implementation_binding']
            observed = bound_json(root,implementation)
            raw = local(root,implementation['path']).read_bytes()
            actual_blob = hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
            if implementation.get('git_blob') != actual_blob or not matching_pair(observed,row['package'],row['version']):
                raise ValueError('Python selected version differs from reviewed implementation binding')
            if data.get('python_version') != manifest.get('python_version') or data.get('exclude_newer') != manifest.get('exclude_newer'):
                raise ValueError('Python target/cutoff binding mismatch')
            observations[key] = checked_official_record(root, row, manifest['exclude_newer'])
        elif row.get('artifact') is not None:
            raise ValueError('R archive was not obtained by this metadata revision')
    if requested != set(manifest['new_packages']):
        raise ValueError('source metadata omits requested packages')
    if manifest['lane'] == 'R':
        inherited = {}
        for row in csv.DictReader(local(root,inventory['path']).read_text().splitlines()):
            name = row.get('package',row.get('Package'))
            if not name or name in inherited: raise ValueError('invalid R lineage inventory')
            inherited[name] = row.get('version',row.get('Version'))
        for row in records:
            if row['scope'] == 'inherited' and inherited.get(row['package']) != row['version']:
                raise ValueError('inherited R package version differs from source binding')
        if set(data.get('forbidden_packages',[])) & inherited.keys():
            raise ValueError('forbidden native engine present in recorded R lineage')
    return data, observations

def python_compatibility(data, observations, manifest, root):
    """Direct metadata comparisons, not a transitive solver or native guarantee."""
    from packaging.requirements import Requirement
    from packaging.specifiers import SpecifierSet
    from packaging.version import Version
    py = manifest['python_version']; minor = '.'.join(py.split('.')[:2])
    environment = {'implementation_name':'cpython','implementation_version':py,
        'os_name':'posix','platform_machine':'x86_64','platform_python_implementation':'CPython',
        'platform_release':'','platform_system':'Linux','platform_version':'',
        'python_full_version':py,'python_version':minor,'sys_platform':'linux','extra':''}
    inventory_path = local(root, data['lineage_baseline']['path'])
    inventory = {}
    for row in csv.DictReader(inventory_path.read_text().splitlines()):
        key = norm(row.get('package', row.get('name', '')))
        if not key or key in inventory: raise ValueError('duplicate/missing inventory package')
        inventory[key] = row['version']
    selected = {norm(r['package']):r['version'] for r in data['packages']}
    available = {**selected, **inventory}  # Immutable inherited versions win.
    conflicts = []; missing = []; extras_skipped = []; evaluated = []
    for package, metadata in observations.items():
        requires_python = metadata.get('requires_python')
        if requires_python and Version(py) not in SpecifierSet(requires_python):
            conflicts.append({'package':package,'dependency':'python','requirement':requires_python,'actual':py})
        for text in metadata.get('requires_dist') or []:
            req = Requirement(text)
            if req.url:
                raise ValueError('unreviewed direct-URL dependency in official metadata')
            if req.marker and not req.marker.evaluate(environment):
                extras_skipped.append({'package':package,'requirement':text}); continue
            name = norm(req.name); actual = available.get(name)
            record = {'package':package,'dependency':name,'requirement':text,'actual':actual}
            evaluated.append(record)
            if actual is None:
                missing.append(record)
            elif req.specifier and Version(actual) not in req.specifier:
                conflicts.append(record)
    return {'basis':'recorded_lineage_inventory_and_direct_selections_not_live_or_unbuilt_parent',
            'environment':environment,'conflicts':conflicts,'missing_direct_dependencies':missing,
            'evaluated':evaluated,'skipped_nonapplicable_markers':extras_skipped,
            'transitive_closure_verified':False,'native_compatibility_verified':False}

def additive_metadata_errors(candidate, manifest, root):
    """Fail before uv/download/build on corrupt bindings or known incompatibility."""
    try:
        inspected = inspect_metadata(candidate, manifest, root)
        if inspected is None or manifest['lane'] != 'py': return []
        data, observations = inspected
        result = python_compatibility(data, observations, manifest, root)
        return ['additive metadata conflict: {package} requires {requirement}; inherited/selected {dependency}={actual}'.format(**r)
                for r in result['conflicts']]
    except (KeyError, TypeError, ValueError, OSError, ImportError) as exc:
        return ['source metadata guard: ' + str(exc)]

def verify_isolated_metadata(root, binding):
    """Check existing reviewed tuples; local builds keep distinct source/wheel SHA."""
    folder = local(root, binding['path'])
    names = {'profile.json':'profile_sha256','OFFICIAL_ARTIFACTS.json':'official_artifacts_sha256','wheels.lock.json':'wheels_lock_sha256'}
    loaded = {}
    for name, key in names.items():
        if digest(folder/name) != binding[key]: raise ValueError('isolated metadata SHA mismatch: ' + name)
        loaded[name] = json.loads((folder/name).read_text())
    profile = loaded['profile.json']; official = loaded['OFFICIAL_ARTIFACTS.json']; lock = loaded['wheels.lock.json']
    if profile.get('baseline_mutation_allowed') is not False or profile.get('production_image_verified') is not False:
        raise ValueError('isolated profile boundary changed')
    cutoff = timestamp(profile['production_resolution_cutoff'])
    if timestamp(official['cutoff']) != cutoff: raise ValueError('isolated cutoff differs')
    artifacts = {}; wheels = {}; built = []
    for row in official['artifacts']:
        key = norm(row['package'])
        if key in artifacts: raise ValueError('duplicate isolated official package')
        official_url(row['url'],'files.pythonhosted.org',row['filename'])
        if not SHA.fullmatch(row['sha256']) or row['yanked'] is not False or timestamp(row['uploaded_utc']) >= cutoff:
            raise ValueError('invalid isolated official hash/cutoff/yank status')
        artifacts[key] = row
    for row in lock['wheels']:
        key = norm(row['package']); original = artifacts.get(key)
        if key in wheels or original is None: raise ValueError('isolated wheel coverage mismatch')
        if row['version'] != original['version'] or row['official_artifact'] != original or not SHA.fullmatch(row['sha256']):
            raise ValueError('isolated official/wheel identity mismatch')
        if row.get('locally_built') is True:
            built.append(row['package'] + '==' + row['version'])
            if original['filename'].endswith('.whl'): raise ValueError('local build must retain source artifact')
        elif row.get('locally_built') is not False or row['filename'] != original['filename'] or row['sha256'] != original['sha256']:
            raise ValueError('downloaded wheel identity mismatch')
        wheels[key] = row
    if set(wheels) != set(artifacts): raise ValueError('isolated source/wheel package set differs')
    if sorted(built, key=str.lower) != sorted(profile['local_builds'], key=str.lower):
        raise ValueError('isolated local-build set differs')
    for name, version in profile['pins'].items():
        if wheels.get(norm(name), {}).get('version') != version:
            raise ValueError('isolated pinned version missing')
    return {'official_artifact_count':len(artifacts),'locked_wheel_count':len(wheels),
            'locally_built':built,'metadata_tuples_valid':True,'current_cache_verified':False,
            'production_image_verified':False,'baseline_mutation_allowed':False,
            'archive_requirement':'Obtain the exact existing artifacts; locally built wheels require their separately locked SHA256. No rebuild-substitution or installation is performed.'}
