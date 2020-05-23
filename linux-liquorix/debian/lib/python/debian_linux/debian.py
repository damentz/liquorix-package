import collections
import collections.abc
import os.path
import re
import unittest

from . import utils


class Changelog(list):
    _top_rules = r"""
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
\;\s+urgency=
(?P<urgency>
    \w+
)
(?:,|\n)
"""
    _top_re = re.compile(_top_rules, re.X)
    _bottom_rules = r"""
^
\ --\ 
(?P<maintainer>
    \S(?:\ ?\S)*
)
\ \ 
(?P<date>
    (.*)
)
\n
"""
    _bottom_re = re.compile(_bottom_rules, re.X)
    _ignore_re = re.compile(r'^(?:  |\s*\n)')

    class Entry(object):
        __slot__ = ('distribution', 'source', 'version', 'urgency',
                    'maintainer', 'date')

        def __init__(self, **kwargs):
            for key, value in kwargs.items():
                setattr(self, key, value)

    def __init__(self, dir='', version=None, file=None):
        if version is None:
            version = Version
        if file:
            self._parse(version, file)
        else:
            with open(os.path.join(dir, "debian/changelog"),
                      encoding="UTF-8") as f:
                self._parse(version, f)

    def _parse(self, version, f):
        top_match = None
        line_no = 0

        for line in f:
            line_no += 1

            if self._ignore_re.match(line):
                pass
            elif top_match is None:
                top_match = self._top_re.match(line)
                if not top_match:
                    raise Exception('invalid top line %d in changelog' %
                                    line_no)
                try:
                    v = version(top_match.group('version'))
                except Exception:
                    if not len(self):
                        raise
                    v = Version(top_match.group('version'))
            else:
                bottom_match = self._bottom_re.match(line)
                if not bottom_match:
                    raise Exception('invalid bottom line %d in changelog' %
                                    line_no)

                self.append(self.Entry(
                    distribution=top_match.group('distribution'),
                    source=top_match.group('source'),
                    version=v,
                    urgency=top_match.group('urgency'),
                    maintainer=bottom_match.group('maintainer'),
                    date=bottom_match.group('date')))
                top_match = bottom_match = None


class Version(object):
    _epoch_re = re.compile(r'\d+$')
    _upstream_re = re.compile(r'[0-9][A-Za-z0-9.+\-:~]*$')
    _revision_re = re.compile(r'[A-Za-z0-9+.~]+$')

    def __init__(self, version):
        try:
            split = version.index(':')
        except ValueError:
            epoch, rest = None, version
        else:
            epoch, rest = version[0:split], version[split+1:]
        try:
            split = rest.rindex('-')
        except ValueError:
            upstream, revision = rest, None
        else:
            upstream, revision = rest[0:split], rest[split+1:]
        if (epoch is not None and not self._epoch_re.match(epoch)) or \
           not self._upstream_re.match(upstream) or \
           (revision is not None and not self._revision_re.match(revision)):
            raise RuntimeError(u"Invalid debian version")
        self.epoch = epoch and int(epoch)
        self.upstream = upstream
        self.revision = revision

    def __str__(self):
        return self.complete

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
        warn(u"debian argument was replaced by revision", DeprecationWarning,
             stacklevel=2)
        return self.revision


class _VersionTest(unittest.TestCase):
    def test_native(self):
        v = Version('1.2+c~4')
        self.assertEqual(v.epoch, None)
        self.assertEqual(v.upstream, '1.2+c~4')
        self.assertEqual(v.revision, None)
        self.assertEqual(v.complete, '1.2+c~4')
        self.assertEqual(v.complete_noepoch, '1.2+c~4')

    def test_nonnative(self):
        v = Version('1-2+d~3')
        self.assertEqual(v.epoch, None)
        self.assertEqual(v.upstream, '1')
        self.assertEqual(v.revision, '2+d~3')
        self.assertEqual(v.complete, '1-2+d~3')
        self.assertEqual(v.complete_noepoch, '1-2+d~3')

    def test_native_epoch(self):
        v = Version('5:1.2.3')
        self.assertEqual(v.epoch, 5)
        self.assertEqual(v.upstream, '1.2.3')
        self.assertEqual(v.revision, None)
        self.assertEqual(v.complete, '5:1.2.3')
        self.assertEqual(v.complete_noepoch, '1.2.3')

    def test_nonnative_epoch(self):
        v = Version('5:1.2.3-4')
        self.assertEqual(v.epoch, 5)
        self.assertEqual(v.upstream, '1.2.3')
        self.assertEqual(v.revision, '4')
        self.assertEqual(v.complete, '5:1.2.3-4')
        self.assertEqual(v.complete_noepoch, '1.2.3-4')

    def test_multi_hyphen(self):
        v = Version('1-2-3')
        self.assertEqual(v.epoch, None)
        self.assertEqual(v.upstream, '1-2')
        self.assertEqual(v.revision, '3')
        self.assertEqual(v.complete, '1-2-3')

    def test_multi_colon(self):
        v = Version('1:2:3')
        self.assertEqual(v.epoch, 1)
        self.assertEqual(v.upstream, '2:3')
        self.assertEqual(v.revision, None)

    def test_invalid_epoch(self):
        with self.assertRaises(RuntimeError):
            Version('a:1')
        with self.assertRaises(RuntimeError):
            Version('-1:1')
        with self.assertRaises(RuntimeError):
            Version('1a:1')

    def test_invalid_upstream(self):
        with self.assertRaises(RuntimeError):
            Version('1_2')
        with self.assertRaises(RuntimeError):
            Version('1/2')
        with self.assertRaises(RuntimeError):
            Version('a1')
        with self.assertRaises(RuntimeError):
            Version('1 2')

    def test_invalid_revision(self):
        with self.assertRaises(RuntimeError):
            Version('1-2_3')
        with self.assertRaises(RuntimeError):
            Version('1-2/3')
        with self.assertRaises(RuntimeError):
            Version('1-2:3')


class VersionLinux(Version):
    _upstream_re = re.compile(r"""
(?P<version>
    \d+\.\d+
)
(?P<update>
    (?:\.\d+)?
    (?:-[a-z]+\d+)?
)
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
$
    """, re.X)
    _revision_re = re.compile(r"""
\d+
(\.\d+)?
(?:
    (?P<revision_experimental>
        ~exp\d+
    )
    |
    (?P<revision_security>
        (?:[~+]deb\d+u\d+)+
    )?
    (?P<revision_backports>
        ~bpo\d+\+\d+
    )?
    |
    (?P<revision_other>
        .+?
    )
)
(?:\+b\d+)?
$
    """, re.X)

    def __init__(self, version):
        super(VersionLinux, self).__init__(version)
        up_match = self._upstream_re.match(self.upstream)
        rev_match = self._revision_re.match(self.revision)
        if up_match is None or rev_match is None:
            raise RuntimeError(u"Invalid debian linux version")
        d = up_match.groupdict()
        self.linux_modifier = d['modifier']
        self.linux_version = d['version']
        if d['modifier'] is not None:
            assert not d['update']
            self.linux_upstream = '-'.join((d['version'], d['modifier']))
        else:
            self.linux_upstream = d['version']
        self.linux_upstream_full = self.linux_upstream + d['update']
        self.linux_dfsg = d['dfsg']
        d = rev_match.groupdict()
        self.linux_revision_experimental = d['revision_experimental'] and True
        self.linux_revision_security = d['revision_security'] and True
        self.linux_revision_backports = d['revision_backports'] and True
        self.linux_revision_other = d['revision_other'] and True


class _VersionLinuxTest(unittest.TestCase):
    def test_stable(self):
        v = VersionLinux('1.2.3-4')
        self.assertEqual(v.linux_version, '1.2')
        self.assertEqual(v.linux_upstream, '1.2')
        self.assertEqual(v.linux_upstream_full, '1.2.3')
        self.assertEqual(v.linux_modifier, None)
        self.assertEqual(v.linux_dfsg, None)
        self.assertFalse(v.linux_revision_experimental)
        self.assertFalse(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_rc(self):
        v = VersionLinux('1.2~rc3-4')
        self.assertEqual(v.linux_version, '1.2')
        self.assertEqual(v.linux_upstream, '1.2-rc3')
        self.assertEqual(v.linux_upstream_full, '1.2-rc3')
        self.assertEqual(v.linux_modifier, 'rc3')
        self.assertEqual(v.linux_dfsg, None)
        self.assertFalse(v.linux_revision_experimental)
        self.assertFalse(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_dfsg(self):
        v = VersionLinux('1.2~rc3.dfsg.1-4')
        self.assertEqual(v.linux_version, '1.2')
        self.assertEqual(v.linux_upstream, '1.2-rc3')
        self.assertEqual(v.linux_upstream_full, '1.2-rc3')
        self.assertEqual(v.linux_modifier, 'rc3')
        self.assertEqual(v.linux_dfsg, '1')
        self.assertFalse(v.linux_revision_experimental)
        self.assertFalse(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_experimental(self):
        v = VersionLinux('1.2~rc3-4~exp5')
        self.assertEqual(v.linux_upstream_full, '1.2-rc3')
        self.assertTrue(v.linux_revision_experimental)
        self.assertFalse(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_security(self):
        v = VersionLinux('1.2.3-4+deb10u1')
        self.assertEqual(v.linux_upstream_full, '1.2.3')
        self.assertFalse(v.linux_revision_experimental)
        self.assertTrue(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_backports(self):
        v = VersionLinux('1.2.3-4~bpo9+10')
        self.assertEqual(v.linux_upstream_full, '1.2.3')
        self.assertFalse(v.linux_revision_experimental)
        self.assertFalse(v.linux_revision_security)
        self.assertTrue(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_security_backports(self):
        v = VersionLinux('1.2.3-4+deb10u1~bpo9+10')
        self.assertEqual(v.linux_upstream_full, '1.2.3')
        self.assertFalse(v.linux_revision_experimental)
        self.assertTrue(v.linux_revision_security)
        self.assertTrue(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_lts_backports(self):
        # Backport during LTS, as an extra package in the -security
        # suite.  Since this is not part of a -backports suite it
        # shouldn't get the linux_revision_backports flag.
        v = VersionLinux('1.2.3-4~deb9u10')
        self.assertEqual(v.linux_upstream_full, '1.2.3')
        self.assertFalse(v.linux_revision_experimental)
        self.assertTrue(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_lts_backports_2(self):
        # Same but with two security extensions in the revision.
        v = VersionLinux('1.2.3-4+deb10u1~deb9u10')
        self.assertEqual(v.linux_upstream_full, '1.2.3')
        self.assertFalse(v.linux_revision_experimental)
        self.assertTrue(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_binnmu(self):
        v = VersionLinux('1.2.3-4+b1')
        self.assertFalse(v.linux_revision_experimental)
        self.assertFalse(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertFalse(v.linux_revision_other)

    def test_other_revision(self):
        v = VersionLinux('4.16.5-1+revert+crng+ready')  # from #898087
        self.assertFalse(v.linux_revision_experimental)
        self.assertFalse(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertTrue(v.linux_revision_other)

    def test_other_revision_binnmu(self):
        v = VersionLinux('4.16.5-1+revert+crng+ready+b1')
        self.assertFalse(v.linux_revision_experimental)
        self.assertFalse(v.linux_revision_security)
        self.assertFalse(v.linux_revision_backports)
        self.assertTrue(v.linux_revision_other)


class PackageArchitecture(collections.abc.MutableSet):
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
        return ' '.join(sorted(self))

    def add(self, value):
        self._data.add(value)

    def discard(self, value):
        self._data.discard(value)

    def extend(self, value):
        if isinstance(value, str):
            for i in re.split(r'\s', value.strip()):
                self.add(i)
        else:
            raise RuntimeError


class PackageDescription(object):
    __slots__ = "short", "long"

    def __init__(self, value=None):
        self.short = []
        self.long = []
        if value is not None:
            desc_split = value.split("\n", 1)
            self.append_short(desc_split[0])
            if len(desc_split) == 2:
                self.append(desc_split[1])

    def __str__(self):
        wrap = utils.TextWrapper(width=74, fix_sentence_endings=True).wrap
        short = ', '.join(self.short)
        long_pars = []
        for i in self.long:
            long_pars.append(wrap(i))
        long = '\n .\n '.join(['\n '.join(i) for i in long_pars])
        return short + '\n ' + long if long else short

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
        return ', '.join(str(i) for i in self)

    def _search_value(self, value):
        for i in self:
            if i._search_value(value):
                return i
        return None

    def append(self, value, override_arches=None):
        if isinstance(value, str):
            value = PackageRelationGroup(value, override_arches)
        elif not isinstance(value, PackageRelationGroup):
            raise ValueError(u"got %s" % type(value))
        j = self._search_value(value)
        if j:
            j._update_arches(value)
        else:
            super(PackageRelation, self).append(value)

    def extend(self, value, override_arches=None):
        if isinstance(value, str):
            value = (j.strip() for j in re.split(r',', value.strip()))
        for i in value:
            self.append(i, override_arches)


class PackageRelationGroup(list):
    def __init__(self, value=None, override_arches=None):
        if value:
            self.extend(value, override_arches)

    def __str__(self):
        return ' | '.join(str(i) for i in self)

    def _search_value(self, value):
        for i, j in zip(self, value):
            if i.name != j.name or i.operator != j.operator or \
               i.version != j.version or i.restrictions != j.restrictions:
                return None
        return self

    def _update_arches(self, value):
        for i, j in zip(self, value):
            if i.arches:
                for arch in j.arches:
                    if arch not in i.arches:
                        i.arches.append(arch)

    def append(self, value, override_arches=None):
        if isinstance(value, str):
            value = PackageRelationEntry(value, override_arches)
        elif not isinstance(value, PackageRelationEntry):
            raise ValueError
        super(PackageRelationGroup, self).append(value)

    def extend(self, value, override_arches=None):
        if isinstance(value, str):
            value = (j.strip() for j in re.split(r'\|', value.strip()))
        for i in value:
            self.append(i, override_arches)


class PackageRelationEntry(object):
    __slots__ = "name", "operator", "version", "arches", "restrictions"

    _re = re.compile(r'^(\S+)(?: \((<<|<=|=|!=|>=|>>)\s*([^)]+)\))?'
                     r'(?: \[([^]]+)\])?(?: <([^>]+)>)?$')

    class _operator(object):
        OP_LT = 1
        OP_LE = 2
        OP_EQ = 3
        OP_NE = 4
        OP_GE = 5
        OP_GT = 6

        operators = {
                '<<': OP_LT,
                '<=': OP_LE,
                '=': OP_EQ,
                '!=': OP_NE,
                '>=': OP_GE,
                '>>': OP_GT,
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
            return self.__class__(
                self.operators_text[self.operators_neg[self._op]])

        def __str__(self):
            return self.operators_text[self._op]

        def __eq__(self, other):
            return type(other) == type(self) and self._op == other._op

    def __init__(self, value=None, override_arches=None):
        if not isinstance(value, str):
            raise ValueError

        self.parse(value)

        if override_arches:
            self.arches = list(override_arches)

    def __str__(self):
        ret = [self.name]
        if self.operator is not None and self.version is not None:
            ret.extend((' (', str(self.operator), ' ', self.version, ')'))
        if self.arches:
            ret.extend((' [', ' '.join(self.arches), ']'))
        if self.restrictions:
            ret.extend((' <', ' '.join(self.restrictions), '>'))
        return ''.join(ret)

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
            self.arches = re.split(r'\s+', match[3])
        else:
            self.arches = []
        if match[4] is not None:
            self.restrictions = re.split(r'\s+', match[4])
        else:
            self.restrictions = []


class _ControlFileDict(dict):
    def __setitem__(self, key, value):
        try:
            cls = self._fields[key]
            if not isinstance(value, cls):
                value = cls(value)
        except KeyError:
            pass
        super(_ControlFileDict, self).__setitem__(key, value)

    def keys(self):
        keys = set(super(_ControlFileDict, self).keys())
        for i in self._fields.keys():
            if i in self:
                keys.remove(i)
                yield i
        for i in sorted(list(keys)):
            yield i

    def items(self):
        for i in self.keys():
            yield (i, self[i])

    def values(self):
        for i in self.keys():
            yield self[i]


class Package(_ControlFileDict):
    _fields = collections.OrderedDict((
        ('Package', str),
        ('Source', str),
        ('Architecture', PackageArchitecture),
        ('Section', str),
        ('Priority', str),
        ('Maintainer', str),
        ('Uploaders', str),
        ('Standards-Version', str),
        ('Build-Depends', PackageRelation),
        ('Build-Depends-Arch', PackageRelation),
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


class TestsControl(_ControlFileDict):
    _fields = collections.OrderedDict((
        ('Tests', str),
        ('Test-Command', str),
        ('Restrictions', str),
        ('Features', str),
        ('Depends', PackageRelation),
        ('Tests-Directory', str),
        ('Classes', str),
    ))


if __name__ == '__main__':
    unittest.main()
