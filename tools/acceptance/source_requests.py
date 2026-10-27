"""Validate declared source-preparation argv; validation never executes commands."""


def validate_preparation(request, locks):
    preparations = request.get('source_preparation', [])
    if not isinstance(preparations, list):
        raise ValueError('source_preparation must be an array')
    seen = set()
    for item in preparations:
        if not isinstance(item, dict):
            raise ValueError('source preparation must be an object')
        candidate = item.get('candidate')
        if not isinstance(candidate, str) or candidate not in locks or candidate in seen:
            raise ValueError('source preparation names unknown/duplicate source lock')
        seen.add(candidate)
        prefix = ['python3', 'tools/env/prepare_locked_sources.py', candidate,
                  '--lock-sha256', locks[candidate]['sha256']]
        if item.get('check') != prefix + ['--check']:
            raise ValueError('source preparation check differs from exact bound lock argv')
        if 'authorized_download' in item and item['authorized_download'] != prefix + ['--download']:
            raise ValueError('source download description differs from exact bound lock argv')
        if 'reviewed_cache_copy' in item and item['reviewed_cache_copy'] != prefix + ['--source-cache', '<reviewed-cache>']:
            raise ValueError('source cache description differs from exact bound lock argv')
        if item.get('build') != ['python3', 'tools/env/build_candidate.py', candidate, '--build']:
            raise ValueError('source preparation build differs from exact candidate argv')
        if item.get('download_is_automatic') is not False:
            raise ValueError('source preparation must keep automatic download disabled')
        if item.get('archive_cache') != candidate + '/sources':
            raise ValueError('source preparation cache differs from exact candidate')
    return None
