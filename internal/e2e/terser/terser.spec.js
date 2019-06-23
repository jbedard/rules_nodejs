check = require('../check.js');
const path = __dirname;

// TODO(jbedard): the right assertions for .map files is to load up the source-map library

describe('terser', () => {
  it('should work with basic file input', () => {
    check(path, 'basic/basic.min.js', 'basic/basic.min_golden.js_');
    check(path, 'basic/basic.min.js.map', 'basic/basic.min_golden.js.map');
  });

  it('should work with directory input', () => {
    check(path, 'dirtest/testdir.min/fum.js', 'dirtest/testdir.min_golden/fum.js_');
    check(path, 'dirtest/testdir.min/index.js', 'dirtest/testdir.min_golden/index.js_');
    check(path, 'dirtest/testdir.min/fum.js.map', 'dirtest/testdir.min_golden/fum.js.map');
    check(path, 'dirtest/testdir.min/index.js.map', 'dirtest/testdir.min_golden/index.js.map');
  });

  it('should support multiple inputs', () => {
    check(path, 'multiple/testdir.min/fum.js', 'multiple/testdir.min_golden/fum.js_');
    check(path, 'multiple/testdir.min/index.js', 'multiple/testdir.min_golden/index.js_');
    check(path, 'multiple/testdir.min/fum.js.map', 'multiple/testdir.min_golden/fum.js.map');
    check(path, 'multiple/testdir.min/index.js.map', 'multiple/testdir.min_golden/index.js.map');

    check(path, 'multiple/first.min.js', 'multiple/first.min_golden.js_');
    check(path, 'multiple/first.min.js.map', 'multiple/first.min_golden.js.map');

    check(path, 'multiple/second.min.js', 'multiple/second.min_golden.js_');
    check(path, 'multiple/second.min.js.map', 'multiple/second.min_golden.js.map');
  });

  it('should support input sourcemaps', () => {
    check(path, 'trans-maps/bundle.cjs.min.js', 'trans-maps/bundle.cjs.min_golden.js_');
    check(path, 'trans-maps/bundle.cjs.min.js.map', 'trans-maps/bundle.cjs.min_golden.js.map');
  });

  it('should support input sourcemaps in directories', () => {
    check(
        path, 'trans-maps-dir/testdir.min/bundle.cjs.js',
        'trans-maps-dir/testdir.min_golden/bundle.cjs.js_');
    check(
        path, 'trans-maps-dir/testdir.min/bundle.cjs.js.map',
        'trans-maps-dir/testdir.min_golden/bundle.cjs.js.map');
    check(
        path, 'trans-maps-dir/testdir.min/bundle.umd.js',
        'trans-maps-dir/testdir.min_golden/bundle.umd.js_');
    check(
        path, 'trans-maps-dir/testdir.min/bundle.umd.js.map',
        'trans-maps-dir/testdir.min_golden/bundle.umd.js.map');
  });
});
