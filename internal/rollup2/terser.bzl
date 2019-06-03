# def _run_terser(ctx, input, output, map_output, debug = False, comments = True, config_name = None, in_source_map = None):
def _run_terser(ctx, bundle, bundel_type):
    debug = ctx.attr.debug
    comments = True
    config_name = ctx.label.name
    map_output = ctx.actions.declare_file(output.basename + ".map", sibling = output)

    #TODO (old args) - determined in "for each .js" loop?
    config_name = None
    in_source_map = None

    # TODO:
    # 1: construct args
    # 2:
    #   traverse `bundle` to find .js + .map pairs
    #   run terser for each .js

    inputs = [input]
    outputs = [output]

    args = ctx.actions.args()

    if map_output:
        # Running terser on an individual file
        if not config_name:
            if debug:
                config_name += ".debug"
        config = ctx.actions.declare_file("_%s.terser.json" % config_name)
        args.add_all(["--config-file", config.path])
        outputs += [map_output, config]

    args.add(input.path)
    args.add_all(["--output", output.path])

    # Source mapping options are comma-packed into one argv
    # see https://github.com/terser-js/terser#command-line-usage
    source_map_opts = ["includeSources", "base=" + ctx.bin_dir.path]
    if in_source_map:
        source_map_opts.append("content=" + in_source_map.path)
        inputs.append(in_source_map)

    # This option doesn't work in the config file, only on the CLI
    args.add_all(["--source-map", ",".join(source_map_opts)])

    if comments:
        args.add("--comments")
    if debug:
        args.add("--debug")
        args.add("--beautify")

    ctx.actions.run(
        progress_message = "Optimizing JavaScript %s [terser]" % output.short_path,
        executable = ctx.executable._terser_wrapped,
        inputs = inputs,
        outputs = outputs,
        arguments = [args],
    )

def _terser(ctx):
    bundle = ctx.attr.bundle[JsBundleProvider]

    return [
        JsBundleProvider(
            es2015 = _run_terser(ctx, bundle.es2015, "es2015"),
            cjs = _run_terser(ctx, bundle.cjs, "CommonJS"),
            amd = _run_terser(ctx, bundle.amd, "AMD"),
            umd = _run_terser(ctx, bundle.umd, "UMD"),
        ),
    ]

terser = rule(
    implementation = _terser,
    attrs = {
        "bundle": attr.label(
            doc = """
                A JsBundle to minify.
            """,
            providers = [JsBundleProvider],
        ),
        "debug": attr.bool(default = False),
        "_terser_wrapped": attr.label(
            executable = True,
            cfg = "host",
            default = Label("//internal/rollup2:terser-wrapped"),
        ),
    },
)
