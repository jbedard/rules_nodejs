# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Rollup bundling

The versions of Rollup and terser are controlled by the Bazel toolchain.
You do not need to install them into your project.
"""

load("@build_bazel_rules_nodejs//internal/common:node_module_info.bzl", "NodeModuleSources", "collect_node_modules_aspect")
load("//internal/common:collect_es6_sources.bzl", _collect_es2015_sources = "collect_es6_sources")
load("//internal/rollup2:bundle_types.bzl", "JsBundleProvider")
load("//internal/common:module_mappings.bzl", "get_module_mappings")

_ROLLUP_MODULE_MAPPINGS_ATTR = "rollup_module_mappings"

def _rollup_module_mappings_aspect_impl(target, ctx):
    mappings = get_module_mappings(target.label, ctx.rule.attr)
    return struct(rollup_module_mappings = mappings)

rollup_module_mappings_aspect = aspect(
    _rollup_module_mappings_aspect_impl,
    attr_aspects = ["deps"],
)

def _trim_package_node_modules(package_name):
    # trim a package name down to its path prior to a node_modules
    # segment. 'foo/node_modules/bar' would become 'foo' and
    # 'node_modules/bar' would become ''
    segments = []
    for n in package_name.split("/"):
        if n == "node_modules":
            break
        segments += [n]
    return "/".join(segments)

# This function is similar but slightly different than _compute_node_modules_root
# in /internal/node/node.bzl. TODO(gregmagolan): consolidate these functions
def _compute_node_modules_root(ctx):
    """Computes the node_modules root from the node_modules and deps attributes.

    Args:
      ctx: the skylark execution context

    Returns:
      The node_modules root as a string
    """
    node_modules_root = None
    for d in ctx.attr.deps:
        if NodeModuleSources in d:
            possible_root = "/".join(["external", d[NodeModuleSources].workspace, "node_modules"])
            if not node_modules_root:
                node_modules_root = possible_root
            elif node_modules_root != possible_root:
                fail("All npm dependencies need to come from a single workspace. Found '%s' and '%s'." % (node_modules_root, possible_root))
    if not node_modules_root:
        # there are no fine grained deps
        # but we still need a node_modules_root even if its empty
        node_modules_root = "node_modules"
    return node_modules_root

def write_rollup_config(ctx, plugins = [], root_dir = None, filename = "_%s.rollup.conf.js", output_format = "iife", additional_entry_points = []):
    """Generate a rollup config file.

    This is also used by the ng_rollup_bundle and ng_package rules in @angular/bazel.

    Args:
      ctx: Bazel rule execution context
      plugins: extra plugins (defaults to [])
               See the ng_rollup_bundle in @angular/bazel for example of usage.
      root_dir: root directory for module resolution (defaults to None)
      filename: output filename pattern (defaults to `_%s.rollup.conf.js`)
      output_format: passed to rollup output.format option, e.g. "umd"
      additional_entry_points: additional entry points for code splitting

    Returns:
      The rollup config file. See https://rollupjs.org/guide/en#configuration-files
    """
    config = ctx.actions.declare_file(filename % ctx.label.name)

    # build_file_path includes the BUILD.bazel file, transform here to only include the dirname
    build_file_dirname = "/".join(ctx.build_file_path.split("/")[:-1])

    entry_points = [ctx.attr.entry_point] + additional_entry_points

    mappings = dict()
    all_deps = ctx.attr.deps + ctx.attr.srcs
    for dep in all_deps:
        if hasattr(dep, _ROLLUP_MODULE_MAPPINGS_ATTR):
            for k, v in getattr(dep, _ROLLUP_MODULE_MAPPINGS_ATTR).items():
                if k in mappings and mappings[k] != v:
                    fail(("duplicate module mapping at %s: %s maps to both %s and %s" %
                          (dep.label, k, mappings[k], v)), "deps")
                mappings[k] = v

    if not root_dir:
        # This must be .es6 to match collect_es6_sources.bzl
        root_dir = "/".join([ctx.bin_dir.path, build_file_dirname, ctx.label.name + ".es6"])

    node_modules_root = _compute_node_modules_root(ctx)

    ctx.actions.expand_template(
        output = config,
        template = ctx.file._rollup_config_tmpl,
        substitutions = {
            "TMPL_additional_plugins": ",\n".join(plugins),
            "TMPL_banner_file": "\"%s\"" % ctx.file.license_banner.path if ctx.file.license_banner else "undefined",
            "TMPL_global_name": ctx.attr.global_name if ctx.attr.global_name else ctx.label.name,
            "TMPL_inputs": ",".join(["\"%s\"" % e for e in entry_points]),
            "TMPL_module_mappings": str(mappings),
            "TMPL_node_modules_root": node_modules_root,
            "TMPL_output_format": output_format,
            "TMPL_rootDir": root_dir,
            "TMPL_stamp_data": "\"%s\"" % ctx.version_file.path if ctx.version_file else "undefined",
            "TMPL_target": str(ctx.label),
            "TMPL_workspace_name": ctx.workspace_name,
        },
    )

    return config

def run_rollup(ctx, sources, config, output):
    """Creates an Action that can run rollup on set of sources.

    This is also used by ng_package and ng_rollup_bundle rules in @angular/bazel.

    Args:
      ctx: Bazel rule execution context
      sources: JS sources to rollup
      config: rollup config file
      output: output file

    Returns:
      the sourcemap output file
    """
    map_output = ctx.actions.declare_file(output.basename + ".map", sibling = output)

    _run_rollup(ctx, sources, config, output, map_output)

    return map_output

def _filter_js_inputs(all_inputs):
    # Note: make sure that "all_inputs" is not a depset.
    # Iterating over a depset is deprecated!
    return [
        f
        for f in all_inputs
        # We also need to include ".map" files as these can be read by
        # the "rollup-plugin-sourcemaps" plugin.
        if f.path.endswith(".js") or f.path.endswith(".json") or f.path.endswith(".map")
    ]

def _run_rollup(ctx, sources, config, output, map_output):
    args = ctx.actions.args()
    args.add_all(["--config", config.path])

    args.add_all(["--output.file", output.path])
    args.add_all(["--output.sourcemap", "--output.sourcemapFile", map_output.path])

    # We will produce errors as needed. Anything else is spammy: a well-behaved
    # bazel rule prints nothing on success.
    args.add("--silent")

    if ctx.attr.globals:
        args.add("--external")
        args.add_joined(ctx.attr.globals.keys(), join_with = ",")
        args.add("--globals")
        args.add_joined(["%s:%s" % g for g in ctx.attr.globals.items()], join_with = ",")

    direct_inputs = [config]

    # Include files from npm fine grained deps as inputs.
    # These deps are identified by the NodeModuleSources provider.
    for d in ctx.attr.deps:
        if NodeModuleSources in d:
            # Note: we can't avoid calling .to_list() on sources
            direct_inputs += _filter_js_inputs(d[NodeModuleSources].sources.to_list())

    if ctx.file.license_banner:
        direct_inputs += [ctx.file.license_banner]
    if ctx.version_file:
        direct_inputs += [ctx.version_file]

    outputs = [output]
    if map_output:
        outputs += [map_output]

    ctx.actions.run(
        progress_message = "Bundling JavaScript %s [rollup]" % output.short_path,
        executable = ctx.executable._rollup,
        inputs = depset(direct_inputs, transitive = [sources]),
        outputs = outputs,
        arguments = [args],
    )

def _rollup_bundle(ctx):
    name = ctx.attr.name
    es2015_sources = _collect_es2015_sources(ctx)

    es2015_config = write_rollup_config(ctx, filename = "_%s.rollup.conf.js", output_format = "esm")
    es2015_js = ctx.actions.declare_file("es2015/%s.js" % name)
    es2015_map = run_rollup(ctx, es2015_sources, es2015_config, es2015_js)

    amd_rollup_config = write_rollup_config(ctx, filename = "_%s_amd.rollup.conf.js", output_format = "amd")
    amd_js = ctx.actions.declare_file("amd/%s.js" % name)
    amd_map = run_rollup(ctx, es2015_sources, amd_rollup_config, amd_js)

    cjs_rollup_config = write_rollup_config(ctx, filename = "_%s_cjs.rollup.conf.js", output_format = "cjs")
    cjs_js = ctx.actions.declare_file("cjs/%s.js" % name)
    cjs_map = run_rollup(ctx, es2015_sources, cjs_rollup_config, cjs_js)

    umd_rollup_config = write_rollup_config(ctx, filename = "_%s_umd.rollup.conf.js", output_format = "umd")
    umd_js = ctx.actions.declare_file("umd/%s.js" % name)
    umd_map = run_rollup(ctx, es2015_sources, umd_rollup_config, umd_js)

    return [
        JsBundleProvider(
            es2015 = depset([es2015_js, es2015_map]),
            amd = depset([amd_js, amd_map]),
            cjs = depset([cjs_js, cjs_map]),
            umd = depset([umd_js, umd_map]),
        ),
    ]

# Expose our list of aspects so derivative rules can override the deps attribute and
# add their own additional aspects.
# If users are in a different repo and load the aspect themselves, they will create
# different Provider symbols (e.g. NodeModuleInfo) and we won't find them.
# So users must use these symbols that are load'ed in rules_nodejs.
ROLLUP_DEPS_ASPECTS = [rollup_module_mappings_aspect, collect_node_modules_aspect]

ROLLUP_ATTRS = {
    "srcs": attr.label_list(
        doc = """JavaScript source files from the workspace.
        These can use ES2015 syntax and ES Modules (import/export)""",
        allow_files = [".js"],
    ),
    "entry_point": attr.label(
        doc = """The starting point of the application, passed as the `--input` flag to rollup.

        If the entry JavaScript file belongs to the same package (as the BUILD file), 
        you can simply reference it by its relative name to the package directory:

        ```
        rollup_bundle(
            name = "bundle",
            entry_point = ":main.js",
        )
        ```

        You can specify the entry point as a typescript file so long as you also include
        the ts_library target in deps:

        ```
        ts_library(
            name = "main",
            srcs = ["main.ts"],
        )

        rollup_bundle(
            name = "bundle",
            deps = [":main"]
            entry_point = ":main.ts",
        )
        ```

        The rule will use the corresponding `.js` output of the ts_library rule as the entry point.

        If the entry point target is a rule, it should produce a single JavaScript entry file that will be passed to the nodejs_binary rule. 
        For example:

        ```
        filegroup(
            name = "entry_file",
            srcs = ["main.js"],
        )

        rollup_bundle(
            name = "bundle",
            entry_point = ":entry_file",
        )
        ```
        """,
        mandatory = True,
        allow_single_file = True,
    ),
    "global_name": attr.string(
        doc = """A name given to this package when referenced as a global variable.
        This name appears in the bundle module incantation at the beginning of the file,
        and governs the global symbol added to the global context (e.g. `window`) as a side-
        effect of loading the UMD/IIFE JS bundle.

        Rollup doc: "The variable name, representing your iife/umd bundle, by which other scripts on the same page can access it."

        This is passed to the `output.name` setting in Rollup.""",
    ),
    "globals": attr.string_dict(
        doc = """A dict of symbols that reference external scripts.
        The keys are variable names that appear in the program,
        and the values are the symbol to reference at runtime in a global context (UMD bundles).
        For example, a program referencing @angular/core should use ng.core
        as the global reference, so Angular users should include the mapping
        `"@angular/core":"ng.core"` in the globals.""",
        default = {},
    ),
    "license_banner": attr.label(
        doc = """A .txt file passed to the `banner` config option of rollup.
        The contents of the file will be copied to the top of the resulting bundles.
        Note that you can replace a version placeholder in the license file, by using
        the special version `0.0.0-PLACEHOLDER`. See the section on stamping in the README.""",
        allow_single_file = [".txt"],
    ),
    "deps": attr.label_list(
        doc = """Other rules that produce JavaScript outputs, such as `ts_library`.""",
        aspects = ROLLUP_DEPS_ASPECTS,
    ),
    "_rollup": attr.label(
        executable = True,
        cfg = "host",
        default = Label("@build_bazel_rules_nodejs//internal/rollup2:rollup"),
    ),
    "_rollup_config_tmpl": attr.label(
        default = Label("@build_bazel_rules_nodejs//internal/rollup2:rollup.config.js"),
        allow_single_file = True,
    ),
}

rollup_bundle = rule(
    implementation = _rollup_bundle,
    attrs = ROLLUP_ATTRS,
)

def _consume_rollup(ctx):
    rollup_output = ctx.attr.bundle[JsBundleProvider]
    type = ctx.attr.type

    if type == "es2015":
        out = rollup_output.es2015
    elif type == "amd":
        out = rollup_output.amd
    elif type == "cjs":
        out = rollup_output.cjs
    elif type == "umd":
        out = rollup_output.umd
    else:
        print("ERROR: invalid bundle type: " % type)

    return DefaultInfo(files = out)

consume_rollup = rule(
    implementation = _consume_rollup,
    attrs = {
        "bundle": attr.label(
            mandatory = True,
        ),
        "type": attr.string(
            mandatory = True,
        ),
    },
)
