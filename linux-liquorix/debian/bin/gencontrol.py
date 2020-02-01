#!/usr/bin/env python3

import sys
sys.path.append("debian/lib/python")

import codecs
import errno
import glob
import io
import os
import os.path
import subprocess

from debian_linux import config
from debian_linux.debian import *
from debian_linux.gencontrol import Gencontrol as Base, merge_packages
from debian_linux.utils import Templates, read_control

class Gencontrol(Base):
    config_schema = {
        'abi': {
            'ignore-changes': config.SchemaItemList(),
        },
        'build': {
            'debug-info': config.SchemaItemBoolean(),
        },
        'description': {
            'parts': config.SchemaItemList(),
        },
        'image': {
            'bootloaders': config.SchemaItemList(),
            'configs': config.SchemaItemList(),
            'initramfs-generators': config.SchemaItemList(),
            'check-size': config.SchemaItemInteger(),
            'check-size-with-dtb': config.SchemaItemBoolean(),
        },
        'relations': {
        },
    }

    def __init__(self, config_dirs=["debian/config"], template_dirs=["debian/templates"]):
        super(Gencontrol, self).__init__(
            config.ConfigCoreHierarchy(self.config_schema, config_dirs),
            Templates(template_dirs),
            VersionLinux)
        self.process_changelog()
        self.config_dirs = config_dirs

    def _setup_makeflags(self, names, makeflags, data):
        for src, dst, optional in names:
            if src in data or not optional:
                makeflags[dst] = data[src]

    def _substitute_file(self, template, vars, target, append=False):
        with codecs.open(target, 'a' if append else 'w', 'utf-8') as f:
            f.write(self.substitute(self.templates[template], vars))

    def do_main_setup(self, vars, makeflags, extra):
        super(Gencontrol, self).do_main_setup(vars, makeflags, extra)
        makeflags.update({
            'VERSION': self.version.linux_version,
            'UPSTREAMVERSION': self.version.linux_upstream,
            'ABINAME': self.abiname_version + self.abiname_part,
            'SOURCEVERSION': self.version.complete,
        })

        """
        # Prepare to generate debian/tests/control
        self.tests_control = None
        """

    def do_main_makefile(self, makefile, makeflags, extra):
        fs_enabled = [featureset
                      for featureset in self.config['base', ]['featuresets']
                      if self.config.merge('base', None, featureset).get('enabled', True)]
        for featureset in fs_enabled:
            makeflags_featureset = makeflags.copy()
            makeflags_featureset['FEATURESET'] = featureset
            cmds_source = ["$(MAKE) -f debian/rules.real source-featureset %s"
                           % makeflags_featureset]
            makefile.add('source_%s_real' % featureset, cmds=cmds_source)
            makefile.add('source_%s' % featureset,
                         ['source_%s_real' % featureset])
            makefile.add('source', ['source_%s' % featureset])

        triplet_enabled = []
        for arch in iter(self.config['base', ]['arches']):
            for featureset in self.config['base', arch].get('featuresets', ()):
                if self.config.merge('base', None, featureset).get('enabled', True):
                    for flavour in self.config['base', arch, featureset]['flavours']:
                        triplet_enabled.append('%s_%s_%s' %
                                               (arch, featureset, flavour))

        makeflags = makeflags.copy()
        makeflags['ALL_FEATURESETS'] = ' '.join(fs_enabled)
        makeflags['ALL_TRIPLETS'] = ' '.join(triplet_enabled)
        super(Gencontrol, self).do_main_makefile(makefile, makeflags, extra)

        # linux-source-$UPSTREAMVERSION will contain all kconfig files
        makefile.add('binary-indep', deps=['setup'])

    def do_main_packages(self, packages, vars, makeflags, extra):
        packages.extend(self.process_packages(self.templates["control.main"], self.vars))

    arch_makeflags = (
        ('kernel-arch', 'KERNEL_ARCH', False),
    )

    def do_arch_setup(self, vars, makeflags, arch, extra):
        config_base = self.config.merge('base', arch)

        self._setup_makeflags(self.arch_makeflags, makeflags, config_base)

    def do_arch_packages(self, packages, makefile, arch, vars, makeflags, extra):
        # Some userland architectures require kernels from another
        # (Debian) architecture, e.g. x32/amd64.
        foreign_kernel = not self.config['base', arch].get('featuresets')

        if self.version.linux_modifier is None:
            try:
                abiname_part = '-%s' % self.config['abi', arch]['abiname']
            except KeyError:
                abiname_part = self.abiname_part
            makeflags['ABINAME'] = vars['abiname'] = \
                self.abiname_version + abiname_part

        """
        if foreign_kernel:
            packages_headers_arch = []
            makeflags['FOREIGN_KERNEL'] = True
        else:
            headers_arch = self.templates["control.headers.arch"]
            packages_headers_arch = self.process_packages(headers_arch, vars)

        libc_dev = self.templates["control.libc-dev"]
        packages_headers_arch[0:0] = self.process_packages(libc_dev, {})

        packages_headers_arch[-1]['Depends'].extend(PackageRelation())
        extra['headers_arch_depends'] = packages_headers_arch[-1]['Depends']

        merge_packages(packages, packages_headers_arch, arch)

        cmds_binary_arch = ["$(MAKE) -f debian/rules.real binary-arch-arch %s" % makeflags]
        makefile.add('binary-arch_%s_real' % arch, cmds=cmds_binary_arch)

        # Shortcut to aid architecture bootstrapping
        makefile.add('binary-libc-dev_%s' % arch,
                     ['source_none_real'],
                     ["$(MAKE) -f debian/rules.real install-libc-dev_%s %s" %
                      (arch, makeflags)])

        if os.getenv('DEBIAN_KERNEL_DISABLE_INSTALLER'):
            if self.changelog[0].distribution == 'UNRELEASED':
                import warnings
                warnings.warn('Disable installer modules on request (DEBIAN_KERNEL_DISABLE_INSTALLER set)')
            else:
                raise RuntimeError('Unable to disable installer modules in release build (DEBIAN_KERNEL_DISABLE_INSTALLER set)')
        else:
            # Add udebs using kernel-wedge
            installer_def_dir = 'debian/installer'
            installer_arch_dir = os.path.join(installer_def_dir, arch)
            if os.path.isdir(installer_arch_dir):
                kw_env = os.environ.copy()
                kw_env['KW_DEFCONFIG_DIR'] = installer_def_dir
                kw_env['KW_CONFIG_DIR'] = installer_arch_dir
                kw_proc = subprocess.Popen(
                    ['kernel-wedge', 'gen-control', vars['abiname']],
                    stdout=subprocess.PIPE,
                    env=kw_env)
                if not isinstance(kw_proc.stdout, io.IOBase):
                    udeb_packages = read_control(io.open(kw_proc.stdout.fileno(), encoding='utf-8', closefd=False))
                else:
                    udeb_packages = read_control(io.TextIOWrapper(kw_proc.stdout, 'utf-8'))
                kw_proc.wait()
                if kw_proc.returncode != 0:
                    raise RuntimeError('kernel-wedge exited with code %d' %
                                       kw_proc.returncode)

                merge_packages(packages, udeb_packages, arch)

                # These packages must be built after the per-flavour/
                # per-featureset packages.  Also, this won't work
                # correctly with an empty package list.
                if udeb_packages:
                    makefile.add(
                        'binary-arch_%s' % arch,
                        cmds=["$(MAKE) -f debian/rules.real install-udeb_%s %s "
                              "PACKAGE_NAMES='%s'" %
                              (arch, makeflags,
                               ' '.join(p['Package'] for p in udeb_packages))])
        """

    def do_featureset_setup(self, vars, makeflags, arch, featureset, extra):
        config_base = self.config.merge('base', arch, featureset)
        makeflags['LOCALVERSION_HEADERS'] = vars['localversion_headers'] = vars['localversion']

    def do_featureset_packages(self, packages, makefile, arch, featureset, vars, makeflags, extra):
        """
        headers_featureset = self.templates["control.headers.featureset"]
        package_headers = self.process_package(headers_featureset[0], vars)

        merge_packages(packages, (package_headers,), arch)

        cmds_binary_arch = ["$(MAKE) -f debian/rules.real binary-arch-featureset %s" % makeflags]
        makefile.add('binary-arch_%s_%s_real' % (arch, featureset), cmds=cmds_binary_arch)
        """

    flavour_makeflags_base = (
        ('compiler', 'COMPILER', False),
        ('kernel-arch', 'KERNEL_ARCH', False),
        ('cflags', 'CFLAGS_KERNEL', True),
        ('override-host-type', 'OVERRIDE_HOST_TYPE', True),
    )

    flavour_makeflags_build = (
        ('image-file', 'IMAGE_FILE', True),
    )

    flavour_makeflags_image = (
        ('install-stem', 'IMAGE_INSTALL_STEM', True),
    )

    flavour_makeflags_other = (
        ('localversion', 'LOCALVERSION', False),
        ('localversion-image', 'LOCALVERSION_IMAGE', True),
    )

    def do_flavour_setup(self, vars, makeflags, arch, featureset, flavour, extra):
        config_base = self.config.merge('base', arch, featureset, flavour)
        config_build = self.config.merge('build', arch, featureset, flavour)
        config_description = self.config.merge('description', arch, featureset, flavour)
        config_image = self.config.merge('image', arch, featureset, flavour)

        vars['class'] = config_description['hardware']
        vars['longclass'] = config_description.get('hardware-long') or vars['class']

        vars['localversion-image'] = vars['localversion']
        override_localversion = config_image.get('override-localversion', None)
        if override_localversion is not None:
            vars['localversion-image'] = vars['localversion_headers'] + '-' + override_localversion
        vars['image-stem'] = config_image.get('install-stem')

        self._setup_makeflags(self.flavour_makeflags_base, makeflags, config_base)
        self._setup_makeflags(self.flavour_makeflags_build, makeflags, config_build)
        self._setup_makeflags(self.flavour_makeflags_image, makeflags, config_image)
        self._setup_makeflags(self.flavour_makeflags_other, makeflags, vars)

    def do_flavour_packages(self, packages, makefile, arch, featureset, flavour, vars, makeflags, extra):
        headers = self.templates["control.headers"]

        config_entry_base = self.config.merge('base', arch, featureset, flavour)
        config_entry_build = self.config.merge('build', arch, featureset, flavour)
        config_entry_description = self.config.merge('description', arch, featureset, flavour)
        config_entry_image = self.config.merge('image', arch, featureset, flavour)
        config_entry_relations = self.config.merge('relations', arch, featureset, flavour)

        compiler = config_entry_base.get('compiler', 'gcc')

        relations_compiler_headers = PackageRelation(
            config_entry_relations.get('headers%' + compiler) or
            config_entry_relations.get(compiler))

        relations_compiler_build_dep = PackageRelation(config_entry_relations[compiler])
        for group in relations_compiler_build_dep:
            for item in group:
                item.arches = [arch]
        packages['source']['Build-Depends'].extend(relations_compiler_build_dep)

        image_fields = {'Description': PackageDescription()}
        for field in 'Depends', 'Provides', 'Suggests', 'Recommends', 'Conflicts', 'Breaks':
            image_fields[field] = PackageRelation(config_entry_image.get(field.lower(), None), override_arches=(arch,))

        generators = config_entry_image['initramfs-generators']
        l = PackageRelationGroup()
        for i in generators:
            i = config_entry_relations.get(i, i)
            l.append(i)
            a = PackageRelationEntry(i)
            if a.operator is not None:
                a.operator = -a.operator
                image_fields['Breaks'].append(PackageRelationGroup([a]))
        for item in l:
            item.arches = [arch]
        image_fields['Depends'].append(l)

        bootloaders = config_entry_image.get('bootloaders')
        if bootloaders:
            l = PackageRelationGroup()
            for i in bootloaders:
                i = config_entry_relations.get(i, i)
                l.append(i)
                a = PackageRelationEntry(i)
                if a.operator is not None:
                    a.operator = -a.operator
                    image_fields['Breaks'].append(PackageRelationGroup([a]))
            for item in l:
                item.arches = [arch]
            image_fields['Suggests'].append(l)

        desc_parts = self.config.get_merge('description', arch, featureset, flavour, 'parts')
        if desc_parts:
            # XXX: Workaround, we need to support multiple entries of the same name
            parts = list(set(desc_parts))
            parts.sort()
            desc = image_fields['Description']
            for part in parts:
                desc.append(config_entry_description['part-long-' + part])
                desc.append_short(config_entry_description.get('part-short-' + part, ''))

        packages_dummy = []
        packages_own = []

        image = self.templates["control.image"]

        vars.setdefault('desc', None)

        image_main = self.process_real_image(image[0], image_fields, vars)
        packages_own.append(image_main)
        packages_own.extend(self.process_packages(image[1:], vars))

        package_headers = self.process_package(headers[0], vars)
        package_headers['Depends'].extend(relations_compiler_headers)
        packages_own.append(package_headers)
        """
        extra['headers_arch_depends'].append('%s (= ${binary:Version})' % packages_own[-1]['Package'])
        """

        build_debug = config_entry_build.get('debug-info')

        if os.getenv('DEBIAN_KERNEL_DISABLE_DEBUG'):
            if self.changelog[0].distribution == 'UNRELEASED':
                import warnings
                warnings.warn('Disable debug infos on request (DEBIAN_KERNEL_DISABLE_DEBUG set)')
                build_debug = False
            else:
                raise RuntimeError('Unable to disable debug infos in release build (DEBIAN_KERNEL_DISABLE_DEBUG set)')

        if build_debug:
            makeflags['DEBUG'] = True
            packages_own.extend(self.process_packages(self.templates['control.image-dbg'], vars))

        merge_packages(packages, packages_own + packages_dummy, arch)

        """
        tests_control = self.process_package(
            self.templates['tests-control.main'][0], vars)
        tests_control['Depends'].append(
            PackageRelationGroup(image_main['Package'],
                                 override_arches=(arch,)))
        if self.tests_control:
            self.tests_control['Depends'].extend(tests_control['Depends'])
        else:
            self.tests_control = tests_control
        """

        def get_config(*entry_name):
            entry_real = ('image',) + entry_name
            entry = self.config.get(entry_real, None)
            if entry is None:
                return None
            return entry.get('configs', None)

        def check_config_default(fail, f):
            for d in self.config_dirs[::-1]:
                f1 = d + '/' + f
                if os.path.exists(f1):
                    return [f1]
            if fail:
                raise RuntimeError("%s unavailable" % f)
            return []

        def check_config_files(files):
            ret = []
            for f in files:
                for d in self.config_dirs[::-1]:
                    f1 = d + '/' + f
                    if os.path.exists(f1):
                        ret.append(f1)
                        break
                else:
                    raise RuntimeError("%s unavailable" % f)
            return ret

        def check_config(default, fail, *entry_name):
            configs = get_config(*entry_name)
            if configs is None:
                return check_config_default(fail, default)
            return check_config_files(configs)

        kconfig = check_config('config', True)
        kconfig.extend(check_config("kernelarch-%s/config" % config_entry_base['kernel-arch'], False))
        kconfig.extend(check_config("%s/config" % arch, True, arch))
        kconfig.extend(check_config("%s/config.%s" % (arch, flavour), False, arch, None, flavour))
        kconfig.extend(check_config("featureset-%s/config" % featureset, False, None, featureset))
        kconfig.extend(check_config("%s/%s/config" % (arch, featureset), False, arch, featureset))
        kconfig.extend(check_config("%s/%s/config.%s" % (arch, featureset, flavour), False, arch, featureset, flavour))
        makeflags['KCONFIG'] = ' '.join(kconfig)
        if build_debug:
            makeflags['KCONFIG_OPTIONS'] = '-o DEBUG_INFO=y'

        cmds_binary_arch = ["$(MAKE) -f debian/rules.real binary-arch-flavour %s" % makeflags]
        if packages_dummy:
            cmds_binary_arch.append(
                "$(MAKE) -f debian/rules.real install-dummy DH_OPTIONS='%s' %s"
                % (' '.join("-p%s" % i['Package'] for i in packages_dummy), makeflags))
        cmds_build = ["$(MAKE) -f debian/rules.real build-arch-flavour %s" % makeflags]
        cmds_setup = ["$(MAKE) -f debian/rules.real setup-arch-flavour %s" % makeflags]
        makefile.add('binary-arch_%s_%s_%s_real' % (arch, featureset, flavour), cmds=cmds_binary_arch)
        makefile.add('build-arch_%s_%s_%s_real' % (arch, featureset, flavour), cmds=cmds_build)
        makefile.add('setup_%s_%s_%s_real' % (arch, featureset, flavour), cmds=cmds_setup)

        # Substitute kernel version etc. into maintainer scripts,
        # translations and lintian overrides
        self._substitute_file('headers.postinst', vars,
                              'debian/linux-headers-%s%s.postinst' %
                              (vars['abiname'], vars['localversion']))
        for name in ['postinst', 'postrm', 'preinst', 'prerm']:
            self._substitute_file('image.%s' % name, vars,
                                  'debian/linux-image-%s%s.%s' %
                                  (vars['abiname'], vars['localversion'], name))
        if build_debug:
            self._substitute_file('image-dbg.lintian-override', vars,
                                  'debian/linux-image-%s%s-dbgsym.lintian-overrides' %
                                  (vars['abiname'], vars['localversion']))

    def process_changelog(self):
        act_upstream = self.changelog[0].version.upstream
        versions = []
        for i in self.changelog:
            if i.version.upstream != act_upstream:
                break
            versions.append(i.version)
        self.versions = versions
        version = self.version = self.changelog[0].version
        if self.version.linux_modifier is not None:
            self.abiname_part = ''
        else:
            self.abiname_part = '-%s' % self.config['abi', ]['abiname']
        # We need to keep at least three version components to avoid
        # userland breakage (e.g. #742226, #745984).
        self.abiname_version = re.sub('^(\d+\.\d+)(?=-|$)', r'\1.0',
                                      self.version.linux_upstream)
        self.vars = {
            'upstreamversion': self.version.linux_upstream,
            'version': self.version.linux_version,
            'source_upstream': self.version.upstream,
            'source_package': self.changelog[0].source,
            'abiname': self.abiname_version + self.abiname_part,
        }
        self.config['version', ] = {'source': self.version.complete,
                                    'upstream': self.version.linux_upstream,
                                    'abiname_base': self.abiname_version,
                                    'abiname': (self.abiname_version +
                                                self.abiname_part)}

        distribution = self.changelog[0].distribution
        if distribution in ('unstable', ):
            if (version.linux_revision_experimental or
                version.linux_revision_backports or
                version.linux_revision_other):
                raise RuntimeError("Can't upload to %s with a version of %s" % (distribution, version))
        if distribution in ('experimental', ):
            if not version.linux_revision_experimental:
                raise RuntimeError("Can't upload to %s with a version of %s" % (distribution, version))
        if distribution.endswith('-security') or distribution.endswith('-lts'):
            if (not version.linux_revision_security or
                version.linux_revision_backports):
                raise RuntimeError("Can't upload to %s with a version of %s" % (distribution, version))
        if distribution.endswith('-backports'):
            if not version.linux_revision_backports:
                raise RuntimeError("Can't upload to %s with a version of %s" % (distribution, version))

    def process_real_image(self, entry, fields, vars):
        entry = self.process_package(entry, vars)
        for key, value in fields.items():
            if key in entry:
                real = entry[key]
                real.extend(value)
            elif value:
                entry[key] = value
        return entry

    def write(self, packages, makefile):
        self.write_config()
        super(Gencontrol, self).write(packages, makefile)
        """
        self.write_tests_control()
        """

    def write_config(self):
        f = open("debian/config.defines.dump", 'wb')
        self.config.dump(f)
        f.close()

    def write_tests_control(self):
        self.write_rfc822(codecs.open("debian/tests/control", 'w', 'utf-8'),
                          [self.tests_control])

if __name__ == '__main__':
    Gencontrol()()
