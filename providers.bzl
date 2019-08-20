"""Providers for interop between JS rules.

This file has to live in the built-in so that all rules can load() the providers
even if users haven't installed any of the packages/*

These providers allows rules to interoperate without knowledge
of each other.

You can think of a provider as a message bus.
A rule "publishes" a message as an instance of the provider, and some other rule
subscribes to these by having a (possibly transitive) dependency on the publisher.

## Debugging

Debug output is considered orthogonal to these providers.
Any output may or may not have user debugging affordances provided, such as
readable minification.
We expect that rules will have a boolean `debug` attribute, and/or accept the `DEBUG`
environment variable.
Note that this means a given build either produces debug or non-debug output.
If users really need to produce both in a single build, they'll need two rules with
differing 'debug' attributes.
"""

JSModuleInfo = provider(
    doc = """TODO""",
    fields = {
        "module_format": "a string like [amd, cjs, esm, iife, umd]",
        "sources": "depset of JavaScript files",
    },
)

JSTransitiveModuleInfo = provider(
    doc = """Same as JSModuleInfo but also includes transitive files.

This is typically provided by an aspect such as sources_apsect.

module_format will only be set to "mixed" if not all transitive deps have the same module_format.
""",
    fields = {
        "module_format": "a string like cjs, umd",
        "sources": "depset of JavaScript files",
    },
)

def collect_js_modules(ctx):
    """TODO: doc"""
    format = None
    result = []
    for src in ctx.attr.srcs:
        if not JSModuleInfo in src:
            result.extend(src.files.to_list())
            continue
        if not format:
            format = src[JSModuleInfo].module_format
        elif format != src[JSModuleInfo].module_format:
            fail("a mix of module_format. TODO: better error message")
        result.extend(src[JSModuleInfo].sources.to_list())
    return JSModuleInfo(
        module_format = format,
        sources = result,
    )

JSNamedModuleInfo = provider(
    doc = """JavaScript files whose module name is self-contained.

For example named AMD/UMD or goog.module format.
These files can be efficiently served with the concatjs bundler.
These outputs should be named "foo.umd.js"
(note that renaming it from "foo.js" doesn't affect the module id)

Historical note: this was the typescript.es5_sources output.
""",
    fields = {
        "sources": "depset of JavaScript files",
    },
)

JSTransitiveNamedModuleInfo = provider(
    doc = """Same as JSNamedModuleInfo but also includes transitive files.

This is typically provided by an aspect such as sources_apsect.
""",
    fields = {
        "sources": "depset of JavaScript files",
    },
)

JSEcmaScriptModuleInfo = provider(
    doc = """JavaScript files (and sourcemaps) that are intended to be consumed by downstream tooling.

They should use modern syntax and ESModules.
These files should typically be named "foo.mjs"
TODO: should we require that?

Historical note: this was the typescript.es6_sources output""",
    fields = {
        "sources": "depset of JavaScript files",
    },
)

JSTransitiveEcmaScriptModuleInfo = provider(
    doc = """Same as JSEcmaScriptModuleInfo but also includes transitive files.

This is typically provided by an aspect such as sources_apsect.
""",
    fields = {
        "sources": "depset of JavaScript files",
    },
)

DeclarationInfo = provider(
    doc = """The DeclarationInfo provider allows JS rules to communicate typing information.

TypeScript's .d.ts files are used as the interop format for describing types.

The ts_library#deps attribute should require that this provider is attached.

Note: historically this was a subset of the string-typed "typescript" provider.
""",
    # TODO: should we have .d.ts.map files too?
    fields = {
        "declarations": "A depset of .d.ts files produced by this rule",
        "transitive_declarations": """A depset of .d.ts files produced by this rule and all its transitive dependencies.
This prevents needing an aspect in rules that consume the typings, which improves performance.""",
    },
)

# TODO: TsickleInfo might be a needed provider to send tsickle_externs and type_blacklisted_declarations
