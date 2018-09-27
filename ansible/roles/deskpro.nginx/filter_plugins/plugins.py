def any_path_is_missing(iterable):
    if not iterable:
        return False

    for stat in iterable.get('results', []):
        # not a stat result?
        if 'stat' not in stat:
            return False

        if not stat['stat']['exists']:
            return True

    return False


class FilterModule(object):
    def filters(self):
        return {
            'any_path_is_missing': any_path_is_missing,
        }
