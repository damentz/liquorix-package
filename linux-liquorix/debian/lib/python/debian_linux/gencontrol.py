import codecs
import os
import re
from collections import OrderedDict

from .debian import Changelog, PackageArchitecture, PackageDescription, \
    PackageRelation, Version


class PackagesList(OrderedDict):
    def append(self, package):
        self[package['Package']] = package

    def extend(self, packages):
        for package in packages:
            self[package['Package']] = package


class Makefile(object):
    def __init__(self):
        self.rules = {}
        self.add('.NOTPARALLEL')

    def add(self, name, deps=None, cmds=None):
        if name in self.rules:
            self.rules[name].add(deps, cmds)
        else:
            self.rules[name] = self.Rule(name, deps, cmds)
        if deps is not None:
            for i in deps:
                if i not in self.rules:
                    self.rules[i] = self.Rule(i)

    def write(self, out):
        for i in sorted(self.rules.keys()):
            self.rules[i].write(out)

    class Rule(object):
        def __init__(self, name, deps=None, cmds=None):
            self.name = name
            self.deps, self.cmds = set(), []
            self.add(deps, cmds)

        def add(self, deps=None, cmds=None):
            if deps is not None:
                self.deps.update(deps)
            if cmds is not None:
                self.cmds.append(cmds)

        def write(self, out):
            deps_string = ''
            if self.deps:
                deps = list(self.deps)
                deps.sort()
                deps_string = ' ' + ' '.join(deps)

            if self.cmds:
                if deps_string:
                    out.write('%s::%s\n' % (self.name, deps_string))
                for c in self.cmds:
                    out.write('%s::\n' % self.name)
                    for i in c:
                        out.write('\t%s\n' % i)
            else:
                out.write('%s:%s\n' % (self.name, deps_string))


class MakeFlags(dict):
    def __str__(self):
        return ' '.join("%s='%s'" % i for i in sorted(self.items()))

    def copy(self):
        return self.__class__(super(MakeFlags, self).copy())


def iter_featuresets(config):
    for featureset in config['base', ]['featuresets']:
        if config.merge('base', None, featureset).get('enabled', True):
            yield featureset


def iter_arches(config):
    return iter(config['base', ]['arches'])


def iter_arch_featuresets(config, arch):
    for featureset in config['base', arch].get('featuresets', []):
        if config.merge('base', arch, featureset).get('enabled', True):
            yield featureset


def iter_flavours(config, arch, featureset):
    return iter(config['base', arch, featureset]['flavours'])


class Gencontrol(object):
    makefile_targets = ('binary-arch', 'build-arch', 'setup')
    makefile_targets_indep = ('binary-indep', 'build-indep', 'setup')

    def __init__(self, config, templates, version=Version):
        self.config, self.templates = config, templates
        self.changelog = Changelog(version=version)
        self.vars = {}

    def __call__(self):
        packages = PackagesList()
        makefile = Makefile()

        self.do_source(packages)
        self.do_main(packages, makefile)
        self.do_extra(packages, makefile)

        self.merge_build_depends(packages)
        self.write(packages, makefile)

    def do_source(self, packages):
        source = self.templates["control.source"][0]
        if not source.get('Source'):
            source['Source'] = self.changelog[0].source
        packages['source'] = self.process_package(source, self.vars)

    def do_main(self, packages, makefile):
        vars = self.vars.copy()

        makeflags = MakeFlags()
        extra = {}

        self.do_main_setup(vars, makeflags, extra)
        self.do_main_makefile(makefile, makeflags, extra)
        self.do_main_packages(packages, vars, makeflags, extra)
        self.do_main_recurse(packages, makefile, vars, makeflags, extra)

    def do_main_setup(self, vars, makeflags, extra):
        pass

    def do_main_makefile(self, makefile, makeflags, extra):
        makefile.add('build-indep',
                     cmds=["$(MAKE) -f debian/rules.real build-indep %s" %
                           makeflags])
        makefile.add('binary-indep',
                     cmds=["$(MAKE) -f debian/rules.real binary-indep %s" %
                           makeflags])

    def do_main_packages(self, packages, vars, makeflags, extra):
        pass

    def do_main_recurse(self, packages, makefile, vars, makeflags, extra):
        for featureset in iter_featuresets(self.config):
            self.do_indep_featureset(packages, makefile, featureset,
                                     vars.copy(), makeflags.copy(), extra)
        for arch in iter_arches(self.config):
            self.do_arch(packages, makefile, arch, vars.copy(),
                         makeflags.copy(), extra)

    def do_extra(self, packages, makefile):
        templates_extra = self.templates.get("control.extra", None)
        if templates_extra is None:
            return

        packages_extra = self.process_packages(templates_extra, self.vars)
        packages.extend(packages_extra)
        extra_arches = {}
        for package in packages_extra:
            arches = package['Architecture']
            for arch in arches:
                i = extra_arches.get(arch, [])
                i.append(package)
                extra_arches[arch] = i
        for arch in sorted(extra_arches.keys()):
            cmds = []
            for i in extra_arches[arch]:
                cmds.append("$(MAKE) -f debian/rules.real install-dummy "
                            "ARCH='%s' DH_OPTIONS='-p%s'" %
                            (arch, i['Package']))
            makefile.add('binary-arch_%s' % arch,
                         ['binary-arch_%s_extra' % arch])
            makefile.add("binary-arch_%s_extra" % arch, cmds=cmds)

    def do_indep_featureset(self, packages, makefile, featureset, vars,
                            makeflags, extra):
        vars['localversion'] = ''
        if featureset != 'none':
            vars['localversion'] = '-' + featureset

        self.do_indep_featureset_setup(vars, makeflags, featureset, extra)
        self.do_indep_featureset_makefile(makefile, featureset, makeflags,
                                          extra)
        self.do_indep_featureset_packages(packages, makefile, featureset,
                                          vars, makeflags, extra)

    def do_indep_featureset_setup(self, vars, makeflags, featureset, extra):
        pass

    def do_indep_featureset_makefile(self, makefile, featureset, makeflags,
                                     extra):
        makeflags['FEATURESET'] = featureset

        for i in self.makefile_targets_indep:
            target1 = i
            target2 = '_'.join((target1, featureset))
            target3 = '_'.join((target2, 'real'))
            makefile.add(target1, [target2])
            makefile.add(target2, [target3])

    def do_indep_featureset_packages(self, packages, makefile, featureset,
                                     vars, makeflags, extra):
        pass

    def do_arch(self, packages, makefile, arch, vars, makeflags, extra):
        vars['arch'] = arch

        self.do_arch_setup(vars, makeflags, arch, extra)
        self.do_arch_makefile(makefile, arch, makeflags, extra)
        self.do_arch_packages(packages, makefile, arch, vars, makeflags, extra)
        self.do_arch_recurse(packages, makefile, arch, vars, makeflags, extra)

    def do_arch_setup(self, vars, makeflags, arch, extra):
        pass

    def do_arch_makefile(self, makefile, arch, makeflags, extra):
        makeflags['ARCH'] = arch

        for i in self.makefile_targets:
            target1 = i
            target2 = '_'.join((target1, arch))
            target3 = '_'.join((target2, 'real'))
            makefile.add(target1, [target2])
            makefile.add(target2, [target3])

    def do_arch_packages(self, packages, makefile, arch, vars, makeflags,
                         extra):
        pass

    def do_arch_recurse(self, packages, makefile, arch, vars, makeflags,
                        extra):
        for featureset in iter_arch_featuresets(self.config, arch):
            self.do_featureset(packages, makefile, arch, featureset,
                               vars.copy(), makeflags.copy(), extra)

    def do_featureset(self, packages, makefile, arch, featureset, vars,
                      makeflags, extra):
        vars['localversion'] = ''
        if featureset != 'none':
            vars['localversion'] = '-' + featureset

        self.do_featureset_setup(vars, makeflags, arch, featureset, extra)
        self.do_featureset_makefile(makefile, arch, featureset, makeflags,
                                    extra)
        self.do_featureset_packages(packages, makefile, arch, featureset, vars,
                                    makeflags, extra)
        self.do_featureset_recurse(packages, makefile, arch, featureset, vars,
                                   makeflags, extra)

    def do_featureset_setup(self, vars, makeflags, arch, featureset, extra):
        pass

    def do_featureset_makefile(self, makefile, arch, featureset, makeflags,
                               extra):
        makeflags['FEATURESET'] = featureset

        for i in self.makefile_targets:
            target1 = '_'.join((i, arch))
            target2 = '_'.join((target1, featureset))
            target3 = '_'.join((target2, 'real'))
            makefile.add(target1, [target2])
            makefile.add(target2, [target3])

    def do_featureset_packages(self, packages, makefile, arch, featureset,
                               vars, makeflags, extra):
        pass

    def do_featureset_recurse(self, packages, makefile, arch, featureset, vars,
                              makeflags, extra):
        for flavour in iter_flavours(self.config, arch, featureset):
            self.do_flavour(packages, makefile, arch, featureset, flavour,
                            vars.copy(), makeflags.copy(), extra)

    def do_flavour(self, packages, makefile, arch, featureset, flavour, vars,
                   makeflags, extra):
        vars['localversion'] += '-' + flavour

        self.do_flavour_setup(vars, makeflags, arch, featureset, flavour,
                              extra)
        self.do_flavour_makefile(makefile, arch, featureset, flavour,
                                 makeflags, extra)
        self.do_flavour_packages(packages, makefile, arch, featureset, flavour,
                                 vars, makeflags, extra)

    def do_flavour_setup(self, vars, makeflags, arch, featureset, flavour,
                         extra):
        for i in (
            ('kernel-arch', 'KERNEL_ARCH'),
            ('localversion', 'LOCALVERSION'),
        ):
            if i[0] in vars:
                makeflags[i[1]] = vars[i[0]]

    def do_flavour_makefile(self, makefile, arch, featureset, flavour,
                            makeflags, extra):
        makeflags['FLAVOUR'] = flavour

        for i in self.makefile_targets:
            target1 = '_'.join((i, arch, featureset))
            target2 = '_'.join((target1, flavour))
            target3 = '_'.join((target2, 'real'))
            makefile.add(target1, [target2])
            makefile.add(target2, [target3])

    def do_flavour_packages(self, packages, makefile, arch, featureset,
                            flavour, vars, makeflags, extra):
        pass

    def process_relation(self, dep, vars):
        import copy
        dep = copy.deepcopy(dep)
        for groups in dep:
            for item in groups:
                item.name = self.substitute(item.name, vars)
                if item.version:
                    item.version = self.substitute(item.version, vars)
        return dep

    def process_description(self, in_desc, vars):
        desc = in_desc.__class__()
        desc.short = self.substitute(in_desc.short, vars)
        for i in in_desc.long:
            desc.append(self.substitute(i, vars))
        return desc

    def process_package(self, in_entry, vars={}):
        entry = in_entry.__class__()
        for key, value in in_entry.items():
            if isinstance(value, PackageRelation):
                value = self.process_relation(value, vars)
            elif isinstance(value, PackageDescription):
                value = self.process_description(value, vars)
            else:
                value = self.substitute(value, vars)
            entry[key] = value
        return entry

    def process_packages(self, entries, vars):
        return [self.process_package(i, vars) for i in entries]

    def substitute(self, s, vars):
        if isinstance(s, (list, tuple)):
            return [self.substitute(i, vars) for i in s]

        def subst(match):
            return vars[match.group(1)]

        return re.sub(r'@([-_a-z0-9]+)@', subst, str(s))

    # Substitute kernel version etc. into maintainer scripts,
    # bug presubj message and lintian overrides
    def substitute_debhelper_config(self, prefix, vars, package_name,
                                    output_dir='debian'):
        for id in ['bug-presubj', 'lintian-overrides', 'maintscript',
                   'postinst', 'postrm', 'preinst', 'prerm']:
            name = '%s.%s' % (prefix, id)
            try:
                template = self.templates[name]
            except KeyError:
                continue
            else:
                target = '%s/%s.%s' % (output_dir, package_name, id)
                with open(target, 'w') as f:
                    f.write(self.substitute(template, vars))
                    os.chmod(f.fileno(),
                             self.templates.get_mode(name) & 0o777)

    def merge_build_depends(self, packages):
        # Merge Build-Depends pseudo-fields from binary packages into the
        # source package
        source = packages["source"]
        arch_all = PackageArchitecture("all")
        for name, package in packages.items():
            if name == "source":
                continue
            dep = package.get("Build-Depends")
            if not dep:
                continue
            del package["Build-Depends"]
            for group in dep:
                for item in group:
                    if package["Architecture"] != arch_all and not item.arches:
                        item.arches = sorted(package["Architecture"])
                    if package.get("Build-Profiles") and not item.restrictions:
                        profiles = package["Build-Profiles"]
                        assert profiles[0] == "<" and profiles[-1] == ">"
                        item.restrictions = re.split(r"\s+", profiles[1:-1])
            if package["Architecture"] == arch_all:
                dep_type = "Build-Depends-Indep"
            else:
                dep_type = "Build-Depends-Arch"
            if dep_type not in source:
                source[dep_type] = PackageRelation()
            source[dep_type].extend(dep)

    def write(self, packages, makefile):
        self.write_control(packages.values())
        self.write_makefile(makefile)

    def write_control(self, list, name='debian/control'):
        self.write_rfc822(codecs.open(name, 'w', 'utf-8'), list)

    def write_makefile(self, makefile, name='debian/rules.gen'):
        f = open(name, 'w')
        makefile.write(f)
        f.close()

    def write_rfc822(self, f, list):
        for entry in list:
            for key, value in entry.items():
                f.write(u"%s: %s\n" % (key, value))
            f.write('\n')


def merge_packages(packages, new, arch):
    for new_package in new:
        name = new_package['Package']
        if name in packages:
            package = packages.get(name)
            package['Architecture'].add(arch)

            for field in ('Depends', 'Provides', 'Suggests', 'Recommends',
                          'Conflicts'):
                if field in new_package:
                    if field in package:
                        v = package[field]
                        v.extend(new_package[field])
                    else:
                        package[field] = new_package[field]

        else:
            new_package['Architecture'] = arch
            packages.append(new_package)
