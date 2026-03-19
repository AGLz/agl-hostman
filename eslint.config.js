// ESLint flat config (v9+) — migração de .eslintrc.js
module.exports = [
  {
    ignores: [
      'node_modules/',
      'src/vendor/',
      'src/node_modules/',
      'vendor/',
      'dist/',
      'build/',
      'coverage/',
      '*.config.js',
      'vite.config.js',
      'webpack.config.js',
      'babel.config.js',
      'docs/',
    ],
  },
  {
    files: ['src/**/*.js', 'tests/**/*.js'],
    languageOptions: {
      ecmaVersion: 2021,
      sourceType: 'commonjs',
      globals: {
        console: 'readonly',
        process: 'readonly',
        Buffer: 'readonly',
        __dirname: 'readonly',
        __filename: 'readonly',
        module: 'readonly',
        require: 'readonly',
        exports: 'readonly',
      },
    },
    rules: {
      'no-console': 'off',
      'no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },
];
