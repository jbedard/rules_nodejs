"""Terser minification
"""

def _run_terser(ctx, input, output, map_output = True, config_name = None, in_source_maps = None):
    """Runs terser on an input file.

    Args:
      ctx: Bazel rule execution context
      input: input file
      output: output file
      config_name: allows callers to control the name of the generated terser configuration,
          which will be `_[config_name].terser.json` in the package where the target is declared
      in_source_maps: sourcemap files for the input file, passed to the "--source-map content="
          option of rollup.

    Returns:
      The sourcemap file
    """

    # Set map_output to a path when set to boolean True
    if map_output == True:
        # Must use the same naming conventions as terser-wrapper.js
        map_output = ctx.actions.declare_file(output.basename + ".map", sibling = output)

    inputs = [input]
    outputs = [output]

    args = ctx.actions.args()

    if map_output:
        # Running terser on an individual file
        if not config_name:
            config_name = ctx.label.name
        config = ctx.actions.declare_file("_%s.terser.json" % config_name)
        args.add_all(["--config-file", config.path])
        outputs += [map_output, config]

    args.add(input.path)
    args.add_all(["--output", output.path])

    # Source mapping options are comma-packed into one argv
    # see https://github.com/terser-js/terser#command-line-usage
    source_map_opts = ["includeSources", "base=" + ctx.bin_dir.path]
    if in_source_maps:
        source_map_opts.append("content=" + ",".join([m.path for m in in_source_maps]))
        inputs.extend(in_source_maps)

    # This option doesn't work in the config file, only on the CLI
    args.add_all(["--source-map", ",".join(source_map_opts)])

    ctx.actions.run(
        progress_message = "Optimizing JavaScript %s [terser]" % output.short_path,
        executable = ctx.executable._terser_wrapped,
        inputs = inputs,
        outputs = outputs,
        arguments = [args],
    )

    if map_output == False:
        return None

    return map_output

def _terser(ctx):
    outputs = depset()

    for src in ctx.files.srcs:
        # TODO: why doesn't src.is_directory work? always returns False...
        if len(src.extension) == 0:
            out_name = src.basename + ".min"
            out_file = ctx.actions.declare_directory(out_name)
            map_output = False
            config_name = ctx.attr.name
        else:
            filename = src.basename[:-len(src.extension) - 1]
            out_name = filename + ".min." + src.extension
            out_file = ctx.actions.declare_file(out_name)
            map_output = True
            config_name = ctx.attr.name + "." + filename

        map_file = _run_terser(
            ctx,
            src,
            out_file,
            map_output,
            config_name = config_name,
            in_source_maps = ctx.files.in_source_maps,
        )

        out_files = [out_file]
        if map_file != None:
            out_files = out_files + [map_file]

        outputs = depset(out_files, transitive = [outputs])

    return [
        DefaultInfo(
            files = outputs,
        ),
    ]

terser = rule(
    implementation = _terser,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "in_source_maps": attr.label_list(allow_files = True),
        "_terser_wrapped": attr.label(
            executable = True,
            cfg = "host",
            default = Label("@build_bazel_rules_nodejs//internal/terser:terser-wrapped"),
        ),
    },
)
