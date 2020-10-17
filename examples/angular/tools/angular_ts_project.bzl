"Shows how to use ts_project(tsc=ngc) to make a drop-in replacement for ng_module"

load("@npm//@bazel/typescript:index.bzl", "ts_project")

def ng_ts_project(name, tsconfig = "//:tsconfig.json", srcs = [], angular_assets = [], **kwargs):
    ts_project(
        name = name,
        tsconfig = tsconfig,
        declaration = True,
        declaration_map = True,
        tsc = "@npm//@angular/compiler-cli/bin:ngc",
        srcs = srcs + angular_assets,
        **kwargs
    )
