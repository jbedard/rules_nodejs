"User configuration to run the terser binary under bazel"

load("@build_bazel_rules_nodejs//:providers.bzl", "JSModuleInfo", "JSNamedModuleInfo", "JSEcmaScriptModuleInfo")

TERSER_ATTRS = {
    "src": attr.label(
        doc = "TODO",
        allow_files = True,
        mandatory = True,
    ),
    # TODO: wire up this attribute
    "config_file": attr.label(
        doc = """A JSON file containing Terser minify() options.

        This is the file you would pass to the --config-file argument in terser's CLI.
        https://github.com/terser-js/terser#minify-options documents the content of the file.
        
        If this isn't supplied, Bazel will use some default settings.""",
        allow_single_file = True,
    ),
    "debug": attr.bool(
        doc = """Configure terser to produce more readable output.

        Instead of setting this attribute, consider setting the DEBUG env variable instead
        DEBUG=true bazel build //my/terser:target
        so that it only affects the current build.
        """,
    ),
    "sourcemap": attr.bool(
        doc = "TODO",
        default = True,
    ),
    "terser_bin": attr.label(
        default = Label("@npm//@bazel/terser/bin:terser"),
        executable = True,
        cfg = "host",
    ),
    "deps": attr.label_list(),
}

TERSER_OUTS = {
    "optimized": "%{name}.js",
}

# Converts a dict to a struct, recursing into a single level of nested dicts.
# This allows users of compile_ts to modify or augment the returned dict before
# converting it to an immutable struct.
def _dict_to_struct(d):
    for key, value in d.items():
        if type(value) == type({}):
            d[key] = struct(**value)
    return struct(**d)

def run_terser(ctx, srcs, maps):
    """TODO: doc"""

    srcs_list = srcs.to_list()

    if len(srcs_list) == 0:
        return None

    # CLI arguments; see https://www.npmjs.com/package/terser#command-line-usage
    args = ctx.actions.args()
    args.add_all([src.path for src in srcs_list])

    output = ctx.actions.declare_file(srcs_list[0].basename)
    outputs = [output]
    map_outputs = []
    args.add_all(["--output", output])

    # TODO: also check the env.DEBUG variable
    debug = ctx.attr.debug
    if debug:
        args.add("--debug")
        args.add("--beautify")

    # See https://github.com/terser-js/terser#minify-options
    # TODO: give user appropriate control over options
    minify_options = {
        "compress": {
            "global_defs": {"ngDevMode": False, "ngI18nClosureMode": False},
            "keep_fnames": not debug,
            "passes": 3,
            "pure_getters": True,
            "reduce_funcs": not debug,
            "reduce_vars": not debug,
            "sequences": not debug,
        },
        "mangle": not debug,
    }

    if maps:
        map_output = ctx.actions.declare_file(output.basename + ".map", sibling = output)
        map_outputs.append(map_output)

        # Source mapping options are comma-packed into one argv
        # see https://github.com/terser-js/terser#command-line-usage
        source_map_opts = ["includeSources", "base=" + ctx.bin_dir.path]
        #if in_source_map:
        #    source_map_opts.append("content=" + in_source_map.path)
        #    inputs.append(in_source_map)

        # This option doesn't work in the config file, only on the CLI
        args.add_all(["--source-map", ",".join(source_map_opts)])
        minify_options["sourceMap"] = {"filename": map_output.path}

    opts = ctx.actions.declare_file("_%s.minify_options.json" % ctx.label.name)
    ctx.actions.write(opts, _dict_to_struct(minify_options).to_json())
    args.add_all(["--config-file", opts.path])

    ctx.actions.run(
        inputs = srcs.to_list() + [opts],
        outputs = outputs,
        executable = ctx.executable.terser_bin,
        arguments = [args],
        progress_message = "Optimizing JavaScript %s [terser]" % (output.short_path),
    )
    return struct(
        sources = outputs,
        sourcemaps = map_outputs,
    )

def _terser(ctx):
    src = ctx.attr.src
    result = []

    # TODO: input sourcemaps for each provider type?

    # DefaultInfo - sources+sourcemaps unioned into DefaultInfo
    if DefaultInfo in src:
        defaults = run_terser(ctx, src[DefaultInfo].files, ctx.attr.sourcemap)
        result.append(DefaultInfo(
            files = depset(defaults.sources + defaults.sourcemaps),
        ))

    # JSModuleInfo
    if JSModuleInfo in src:
        module = src[JSModuleInfo]
        module_outputs = run_terser(ctx, module.sources, module.sourcemaps)
        result.append(JSModuleInfo(
            module_format = module.module_format,
            sources = depset(module_outputs.sources),
            sourcemaps = depset(module_outputs.sourcemaps),
        ))

    # JSNamedModuleInfo
    if JSNamedModuleInfo in src:
        module = src[JSNamedModuleInfo]
        module_outputs = run_terser(ctx, module.sources, module.sourcemaps)
        result.append(JSNamedModuleInfo(
            sources = depset(module_outputs.sources),
            sourcemaps = depset(module_outputs.sourcemaps),
        ))

    # JSEcmaScriptModuleInfo
    if JSEcmaScriptModuleInfo in src:
        module = src[JSEcmaScriptModuleInfo]
        module_outputs = run_terser(ctx, module.sources, module.sourcemaps)
        result.append(JSEcmaScriptModuleInfo(
            sources = depset(module_outputs.sources),
            sourcemaps = depset(module_outputs.sourcemaps),
        ))

    return result

terser_minified = rule(
    implementation = _terser,
    attrs = TERSER_ATTRS,
    outputs = TERSER_OUTS,
)
