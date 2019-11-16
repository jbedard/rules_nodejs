import {EXPORTED_LIBRARY_THING as v4} from '@special/subdirindex';
import {EXPORTED_LIBRARY_THING as v5} from '@special/subdirindex/index';
import {EXPORTED_LIBRARY_THING as v6} from '@special/subdirindex/lib';

import {EXPORTED_LIBRARY_THING as v1} from './subdirindex';
import {EXPORTED_LIBRARY_THING as v2} from './subdirindex/index';
import {EXPORTED_LIBRARY_THING as v3} from './subdirindex/lib';

describe('dir/index.ts importing', () => {
  it('should import "subdirindex/index" via "subdirindex"', () => {
    expect(v1).toBe(v2);
    expect(v2).toBe(v3);
    expect(v3).toBe(v4);
    expect(v4).toBe(v5);
    expect(v5).toBe(v6);
  });
});
