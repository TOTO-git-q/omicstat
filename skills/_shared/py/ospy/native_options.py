"""Convert explicitly declared CLI native options without evaluating Python code."""
import json
from .errors import OmicstatError


def resolve(args, kinds):
    result = {}
    for name, kind in kinds.items():
        value = args[name]
        try:
            if kind == 'boolean':
                value = {'on': True, 'off': False, 'none': None}[value]
            elif kind in ('object', 'list') and value is not None:
                value = json.loads(value)
                expected = dict if kind == 'object' else list
                if not isinstance(value, expected) or (kind == 'list' and not all(isinstance(x, str) for x in value)):
                    raise ValueError('expected JSON ' + kind)
            elif kind == 'groups' and value != 'all':
                value = json.loads(value)
                if not isinstance(value, list) or not value or not all(isinstance(x, str) for x in value):
                    raise ValueError('expected all or a nonempty JSON list of group names')
            elif kind == 'nullable_string' and value == 'none':
                value = None
            elif kind == 'partition':
                if value == 'none':
                    value = None
                else:
                    import leidenalg
                    value = getattr(leidenalg, value)
        except (ValueError, KeyError, AttributeError, TypeError) as exc:
            raise OmicstatError('OS_INVALID_PARAMETER', '--%s: %s' % (name, exc)) from exc
        result[name] = value
    return result


def serializable(options):
    return {key: value.__module__ + '.' + value.__name__ if isinstance(value, type) else value
            for key, value in options.items()}
