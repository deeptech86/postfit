/**
 * Custom Test Sequencer
 * Ensures auth.test.js runs first, then other tests
 */

const Sequencer = require('@jest/test-sequencer').default;

class CustomSequencer extends Sequencer {
  sort(tests) {
    const copyTests = Array.from(tests);

    // Sort tests so auth.test.js runs first
    return copyTests.sort((testA, testB) => {
      const pathA = testA.path;
      const pathB = testB.path;

      // auth.test.js should always run first
      if (pathA.includes('auth.test.js')) return -1;
      if (pathB.includes('auth.test.js')) return 1;

      // Then alphabetically for the rest
      return pathA.localeCompare(pathB);
    });
  }
}

module.exports = CustomSequencer;
