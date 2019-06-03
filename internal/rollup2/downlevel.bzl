load("//internal/rollup2:bundle_types.bzl", "JsBundleProvider")

# TODO: fix sourcemaps
# tsc does not accept an input sourcemap, but we can combine the input sourcemap
# and tsc outputted sourcemap.
# See PoC:
# https://github.com/jbedard/rules_nodejs/commit/46d2f7db600580d8832980f426c5763df86a8157#diff-c079ccfcce126f3ccb7220f9a67eedc7R225

def _run_tsc(ctx, files, bundle_type, target):
    out = depset()

    for src in files:
        if src.path.endswith(".map"):
            continue

        input = src
        output = ctx.actions.declare_file(target + "/" + input.basename, sibling = input)

        args = ctx.actions.args()

        # No types needed since we are just downleveling.
        # `--types` proceeded by another config argument means an empty types array
        # for the command line parser.
        # See https://github.com/Microsoft/TypeScript/issues/18581#issuecomment-330700612
        args.add("--types")
        args.add("--skipLibCheck")
        args.add_all(["--lib", "es2015,dom"])
        args.add("--allowJS")
        args.add_all(["--target", target])
        args.add_all(["--module", bundle_type])
        args.add_all(["--outDir", output.dirname])
        args.add(input.path)

        ctx.actions.run(
            progress_message = "Downleveling JavaScript to %s %s" % (target, input.short_path),
            executable = ctx.executable._tsc,
            inputs = [input],
            outputs = [output],
            arguments = [args],
        )

        out = depset([output], transitive = [out])

    return out

def _downlevel(ctx):
    bundle = ctx.attr.bundle[JsBundleProvider]
    target = "es5"

    return [
        JsBundleProvider(
            es2015 = _run_tsc(ctx, bundle.es2015, "es2015", target),
            cjs = _run_tsc(ctx, bundle.cjs, "CommonJS", target),
            amd = _run_tsc(ctx, bundle.amd, "AMD", target),
            umd = _run_tsc(ctx, bundle.umd, "UMD", target),
        ),
    ]

downlevel = rule(
    implementation = _downlevel,
    attrs = {
        "bundle": attr.label(
            doc = """
                A JsBundle to downlevel.
                Souce will be downleveled while bundle import/export will remain as-is.
            """,
            providers = [JsBundleProvider],
        ),

        # tsc used to downlevel
        "_tsc": attr.label(
            executable = True,
            cfg = "host",
            default = Label("@build_bazel_rules_nodejs//internal/rollup2:tsc"),
        ),
    },
)
"""
Produces ES5.

Output files will be suffixed with .es5.js.

Accepts JsBundleProvider as input and produces JsBundleProvider with downleveled content.
"""
