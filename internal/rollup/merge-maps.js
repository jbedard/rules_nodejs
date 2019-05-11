// A wrapper around merge-source-map that merges two sourcemaps
// and updates sourceMapURL references to them

const fs = require('fs');
const path = require('path');
const mergeSourceMaps = require('merge-source-map')

const DEBUG = false;

const [js, outJS, map1, map2, outMap] = process.argv.slice(2);

if (DEBUG) {
  console.error(`merge-maps: ${js} => ${outJS}`);
  console.error(`merge-maps: ${map1} + ${map2} => ${outMap}`);
}

// Move the temp-js file and replace the sourcemap map1 references with outMap
const mappingStart = Date.now();
temp_js = fs.readFileSync(js).toString().split('\n');
while (!temp_js[temp_js.length - 1].trim() ||
       /^\s*\/\/\s*#\s*sourceMappingURL=.*$/.test(temp_js[temp_js.length - 1])) {
  temp_js.pop();
}
temp_js.push('//# sourceMappingURL=' + path.basename(outMap));
fs.writeFileSync(outJS, temp_js.join('\n'));

if (DEBUG) {
  console.error(`merge-maps: js map referencing - ${Date.now() - mappingStart}ms`);
}

// Combine the two maps
const mergingStart = Date.now();
fs.writeFileSync(
    outMap,
    JSON.stringify(
        mergeSourceMaps(JSON.parse(fs.readFileSync(map1)), JSON.parse(fs.readFileSync(map2)))));

if (DEBUG) {
  console.error(`merge-maps: map merge - ${Date.now() - mergingStart}ms`);
}