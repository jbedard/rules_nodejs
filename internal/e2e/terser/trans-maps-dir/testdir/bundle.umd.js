/**
 * @license A dummy license banner that goes at the top of the file.
 * This is version v1.2.3
 */

(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('some_global_var')) :
  typeof define === 'function' && define.amd ? define(['exports', 'some_global_var'], factory) :
  (global = global || self, factory(global.bundle = {}, global.runtime_name_of_global_var));
}(this, function (exports, some_global_var) { 'use strict';

  const fum = 'Wonderland';

  var hello = 'Hello';

  const name = 'Alice';

  console.log(`${hello}, ${name} in ${fum}`);

  // Test for sequences = false
  class A {
    a() {
      return document.a;
    }
  }
  function inline_me() {
    return 'abc';
  }
  console.error(new A().a(), inline_me(), some_global_var.thing, ngDevMode, ngI18nClosureMode);
  ngDevMode && console.log('ngDevMode is truthy');
  ngI18nClosureMode && console.log('ngI18nClosureMode is truthy');

  exports.A = A;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=bundle.umd.js.map
