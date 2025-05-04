module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'plugin:@typescript-eslint/recommended',
  ],
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module',
  },
  rules: {
    '@typescript-eslint/no-explicit-any': 'warn', // Change from error to warning
    '@typescript-eslint/no-var-requires': 'warn', // Change from error to warning for test files
  },
  overrides: [
    {
      // For test files, relax some rules
      files: ['**/*.test.ts', '**/test/**/*.ts', '**/e2e/**/*.ts'],
      rules: {
        '@typescript-eslint/no-explicit-any': 'off',
        '@typescript-eslint/no-var-requires': 'off',
      },
    },
  ],
};