import collections
import os.path
import re
import six
import six.moves

from . import utils


class Changelog(list):
    _rules = r"""
^
(?P<source>
    \w[-+0-9a-z.]+
)
\ 
\(
(?P<version>
    [^\(\)\ \t]+
)
\)
\s+
(?P<distribution>
    [-+0-9a-zA-Z.]+
)
\;
"""
    _re = re.compile(_rules, re.X)

    class Entry(object):
        __slot__ = 'distribution', 'source', 'version'

        def __init__(self, distribution, source, version):
            self.distribution, self.source, self.version = distribution, source, version

    def __init__(self, dir='', version=None):
        if version is None:
            version = Version
        if six.PY3:
            f = open(os.path.join(dir, "debian/changelog"), encoding="UTF-8")
        else:
            f = open(os.path.join(dir, "debian/changelog"))
        while True:
            line = f.readline()
            if not line:
                break
            match = self._re.match(line)
            if not match:
                continue
            try:
                v = version(match.group('version'))
            except Exception:
                if not len(self):
                    raise
                v = Version(match.group('version'))
            self.append(self.Entry(match.group('distribution'), match.group('source'), v))


class Version(object):
    _version_rules = r"""
^
(?:
    (?P<epoch>
        \d+
    )
    :
)?
(?P<upstream>
    .+?
)   
(?:
    -
    (?P<revision>[^-]+)
)?
$
"""
    _version_re = re.compile(_version_rules, re.X)

    def __init__(self, version):
        match = self._version_re.match(version)
        if match is None:
            raise RuntimeError(u"Invalid debian version")
        self.epoch = None
        if match.group("epoch") is not None:
            self.epoch = int(match.group("epoch"))
        self.upstream = match.group("upstream")
        self.revision = match.group("revision")

    def __str__(self):
        return self.complete
    __unicode__ = __str__

    @property
    def complete(self):
        if self.epoch is not None:
            return u"%d:%s" % (self.epoch, self.complete_noepoch)
        return self.complete_noepoch

    @property
    def complete_noepoch(self):
        if self.revision is not None:
            return u"%s-%s" % (self.upstream, self.revision)
        return self.upstream

    @property
    def debian(self):
        from warnings import warn
        warn(u"debian argument was replaced by revision", DeprecationWarning, stacklevel=2)
        return self.revision


class VersionLinux(Version):
    _version_linux_rules = r"""
^
(?P<version>
    \d+\.\d+
)
(?P<update>
    \.\d+
)?
(?:
    ~
    (?P<modifier>
        .+?
    )
)?
(?:
    \.dfsg\.
    (?P<dfsg>
        \d+
    )
)?
-
\d+
(\.\d+)?
(?:
    (?P<revision_experimental>
        ~exp\d+
    )
    |
    (?P<revision_backports>
        ~bpo\d\d\+\d+
    )
    |
    (?P<revision_other>
        [^-]+
    )
)?
$
"""
    _version_linux_re = re.compile(_version_linux_rules, re.X)

    def __init__(self, version):
        super(VersionLinux, self).__init__(version)
        match = self._version_linux_re.match(version)
        if match is None:
            raise RuntimeError(u"Invalid debian linux version")
        d = match.groupdict()
        self.linux_modifier = d['modifier']
        self.linux_version = d['version']
        if d['modifier'] is not None:
            assert not d['update']
            self.linux_upstream = u'-'.join((d['version'], d['modifier']))
        else:
            self.linux_upstream = d['version']
        self.linux_upstream_full = self.linux_upstream + (d['update'] or u'')
        self.linux_dfsg = d['dfsg']
        self.linux_revision_experimental = match.group('revision_experimental') and True
        self.linux_revision_backports = match.group('revision_backports') and True
        self.linux_revision_other = match.group('revision_other') and True


class PackageArchitecture(collections.MutableSet):
    __slots__ = '_data'

    def __init__(self, value=None):
        self._data = set()
        if value:
            self.extend(value)

    def __contains__(self, value):
        return self._data.__contains__(value)

    def __iter__(self):
        return self._data.__iter__()

    def __len__(self):
        return self._data.__len__()

    def __str__(self):
        return u' '.join(sorted(self))
    __unicode__ = __str__

    def add(self, value):
        self._data.add(value)

    def discard(self, value):
        self._data.discard(value)

    def extend(self, value):
        if isinstance(value, six.string_types):
            for i in re.split('\s', value.strip()):
                self.add(i)
        else:
            raise RuntimeError


class PackageDescription(object):
    __slots__ = "short", "long"

    def __init__(self, value=None):
        self.short = []
        self.long = []
        if value is not None:
            short, long = value.split(u"\n", 1)
            self.append(long)
            self.append_short(short)

    def __str__(self):
        wrap = utils.TextWrapper(width=74, fix_sentence_endings=True).wrap
        short = u', '.join(self.short)
        long_pars = []
        for i in self.long:
            long_pars.append(wrap(i))
        long = u'\n .\n '.join([u'\n '.join(i) for i in long_pars])
        return short + u'\n ' + long
    __unicode__ = __str__

    def append(self, str):
        str = str.strip()
        if str:
            self.long.extend(str.split(u"\n.\n"))

    def append_short(self, str):
        for i in [i.strip() for i in str.split(u",")]:
            if i:
                self.short.append(i)

    def extend(self, desc):
        if isinstance(desc, PackageDescription):
            self.short.extend(desc.short)
            self.long.extend(desc.long)
        else:
            raise TypeError


class PackageRelation(list):
    def __init__(self, value=None, override_arches=None):
        if value:
            self.extend(value, override_arches)

    def __str__(self):
        return u', '.join(six.text_type(i) for i in self)
    __unicode__ = __str__

    def _search_value(self, value):
        for i in self:
            if i._search_value(value):
                return i
        return None

    def append(self, value, override_arches=None):
        if isinstance(value, six.string_types):
            value = PackageRelationGroup(value, override_arches)
        elif not isinstance(value, PackageRelationGroup):
            raise ValueError(u"got %s" % type(value))
        j = self._search_value(value)
        if j:
            j._update_arches(value)
        else:
            super(PackageRelation, self).append(value)

    def extend(self, value, override_arches=None):
        if isinstance(value, six.string_types):
            value = (j.strip() for j in re.split(u',', value.strip()))
        for i in value:
            self.append(i, override_arches)


class PackageRelationGroup(list):
    def __init__(self, value=None, override_arches=None):
        if value:
            self.extend(value, override_arches)

    def __str__(self):
        return u' | '.join(six.text_type(i) for i in self)
    __unicode__ = __str__

    def _search_value(self, value):
        for i, j in six.moves.zip(self, value):
            if i.name != j.name or i.version != j.version:
                return None
        return self

    def _update_arches(self, value):
        for i, j in six.moves.zip(self, value):
            if i.arches:
                for arch in j.arches:
                    if arch not in i.arches:
                        i.arches.append(arch)

    def append(self, value, override_arches=None):
        if isinstance(value, six.string_types):
            value = PackageRelationEntry(value, override_arches)
        elif not isinstance(value, PackageRelationEntry):
            raise ValueError
        super(PackageRelationGroup, self).append(value)

    def extend(self, value, override_arches=None):
        if isinstance(value, six.string_types):
            value = (j.strip() for j in re.split('\|', value.strip()))
        for i in value:
            self.append(i, override_arches)


class PackageRelationEntry(object):
    __slots__ = "name", "operator", "version", "arches"

    _re = re.compile(r'^(\S+)(?: \((<<|<=|=|!=|>=|>>)\s*([^)]+)\))?(?: \[([^]]+)\])?$')

    class _operator(object):
        OP_LT = 1
        OP_LE = 2
        OP_EQ = 3
        OP_NE = 4
        OP_GE = 5
        OP_GT = 6

        operators = {
                u'<<': OP_LT,
                u'<=': OP_LE,
                u'=': OP_EQ,
                u'!=': OP_NE,
                u'>=': OP_GE,
                u'>>': OP_GT,
        }

        operators_neg = {
                OP_LT: OP_GE,
                OP_LE: OP_GT,
                OP_EQ: OP_NE,
                OP_NE: OP_EQ,
                OP_GE: OP_LT,
                OP_GT: OP_LE,
        }

        operators_text = dict((b, a) for a, b in operators.items())

        __slots__ = '_op',

        def __init__(self, value):
            self._op = self.operators[value]

        def __neg__(self):
            return self.__class__(self.operators_text[self.operators_neg[self._op]])

        def __str__(self):
            return self.operators_text[self._op]
        __unicode__ = __str__

    def __init__(self, value=None, override_arches=None):
        if not isinstance(value, six.string_types):
            raise ValueError

        self.parse(value)

        if override_arches:
            self.arches = list(override_arches)

    def __str__(self):
        ret = [self.name]
        if self.operator is not None and self.version is not None:
            ret.extend((u' (', six.text_type(self.operator), u' ', self.version, u')'))
        if self.arches:
            ret.extend((u' [', u' '.join(self.arches), u']'))
        return u''.join(ret)
    __unicode__ = __str__

    def parse(self, value):
        match = self._re.match(value)
        if match is None:
            raise RuntimeError(u"Can't parse dependency %s" % value)
        match = match.groups()
        self.name = match[0]
        if match[1] is not None:
            self.operator = self._operator(match[1])
        else:
            self.operator = None
        self.version = match[2]
        if match[3] is not None:
            self.arches = re.split('\s+', match[3])
        else:
            self.arches = []


class Package(dict):
    _fields = collections.OrderedDict((
        ('Package', six.text_type),
        ('Source', six.text_type),
        ('Architecture', PackageArchitecture),
        ('Section', six.text_type),
        ('Priority', six.text_type),
        ('Maintainer', six.text_type),
        ('Uploaders', six.text_type),
        ('Standards-Version', six.text_type),
        ('Build-Depends', PackageRelation),
        ('Build-Depends-Indep', PackageRelation),
        ('Provides', PackageRelation),
        ('Pre-Depends', PackageRelation),
        ('Depends', PackageRelation),
        ('Recommends', PackageRelation),
        ('Suggests', PackageRelation),
        ('Replaces', PackageRelation),
        ('Breaks', PackageRelation),
        ('Conflicts', PackageRelation),
        ('Description', PackageDescription),
    ))

    def __setitem__(self, key, value):
        try:
            cls = self._fields[key]
            if not isinstance(value, cls):
                value = cls(value)
        except KeyError:
            pass
        super(Package, self).__setitem__(key, value)

    def iterkeys(self):
        keys = set(self.keys())
        for i in self._fields.keys():
            if i in self:
                keys.remove(i)
                yield i
        for i in keys:
            yield i

    def iteritems(self):
        for i in self.iterkeys():
            yield (i, self[i])

    def itervalues(self):
        for i in self.iterkeys():
            yield self[i]
