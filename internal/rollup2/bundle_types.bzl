JsBundleTypes = [
    "es2015",
    "amd",
    "cjs",
    "umd",
]

"""
A provider encompasing different JavaScript bundle/module types.

A bundle should contain:
    - the JavaScript src code in the bundle type
    - src sourcemaps for the JavaScript

The JavaScript type (es5, es2015) and minification (normal, minified, debug)
is dependent on how the provider was constructed.
"""
JsBundleProvider = provider(fields = JsBundleTypes)
