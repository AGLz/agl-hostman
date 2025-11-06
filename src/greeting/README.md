# Greeting Module

A modular, extensible greeting system implementing multiple greeting formats with clean interfaces and comprehensive documentation.

## Features

- ✅ **Multiple Formats**: Simple, Enhanced, and Creative greetings
- ✅ **Type Safety**: JSDoc type definitions for all functions
- ✅ **Error Handling**: Proper validation and error messages
- ✅ **Extensible Design**: Factory pattern for easy format addition
- ✅ **Best Practices**: SOLID principles, DRY, KISS
- ✅ **Well Documented**: Comprehensive JSDoc comments
- ✅ **Batch Processing**: Multiple greetings in one call

## Installation

```javascript
const greeting = require('./src/greeting');
```

## Usage Examples

### Simple Greeting

```javascript
const { simpleGreeting } = require('./src/greeting');

const result = simpleGreeting();
console.log(result.message); // 'hello'

const custom = simpleGreeting('hi there');
console.log(custom.message); // 'hi there'
```

### Enhanced Greeting

```javascript
const { enhancedGreeting } = require('./src/greeting');

// Basic enhanced
const result = enhancedGreeting({ recipient: 'World' });
console.log(result.message); // 'hello, World'

// Formal greeting
const formal = enhancedGreeting({
  recipient: 'Dr. Smith',
  formal: true
});
console.log(formal.message); // 'Good day, Dr. Smith'
```

### Creative Greeting (Time-aware)

```javascript
const { creativeGreeting } = require('./src/greeting');

// Morning greeting (enthusiastic)
const morning = creativeGreeting({
  recipient: 'Team',
  style: 'enthusiastic'
});
console.log(morning.message); // 'Good morning, Team!'

// Evening greeting (friendly)
const evening = creativeGreeting({
  recipient: 'Friend',
  time: new Date('2025-11-01T19:00:00'),
  style: 'friendly'
});
console.log(evening.message); // 'Good evening, Friend'
```

### Factory Pattern

```javascript
const { greetingFactory } = require('./src/greeting');

// Create any format type
const simple = greetingFactory('simple');
const enhanced = greetingFactory('enhanced', { recipient: 'User' });
const creative = greetingFactory('creative', { style: 'casual' });
```

### Batch Processing

```javascript
const { batchGreeting } = require('./src/greeting');

const results = batchGreeting([
  { format: 'simple' },
  { format: 'enhanced', options: { recipient: 'Team', formal: true } },
  { format: 'creative', options: { style: 'enthusiastic' } }
]);

results.forEach(result => {
  console.log(`[${result.format}] ${result.message}`);
});
```

## API Reference

### Functions

#### `simpleGreeting([message])`

Returns a basic greeting message.

- **Parameters**:
  - `message` (string, optional): Custom message (default: 'hello')
- **Returns**: `GreetingResult` object
- **Throws**: `TypeError` if message is not a string

#### `enhancedGreeting([options])`

Returns greeting with additional context and formatting.

- **Parameters**:
  - `options.message` (string, optional): Base message
  - `options.recipient` (string, optional): Recipient name
  - `options.formal` (boolean, optional): Use formal tone
- **Returns**: `GreetingResult` object with metadata

#### `creativeGreeting([options])`

Returns contextual greeting based on time of day.

- **Parameters**:
  - `options.recipient` (string, optional): Recipient name
  - `options.time` (Date, optional): Time for context
  - `options.style` (string, optional): Greeting style ('friendly', 'enthusiastic', 'formal', 'casual')
- **Returns**: `GreetingResult` object with metadata

#### `greetingFactory(format, [options])`

Factory function to create greetings by format type.

- **Parameters**:
  - `format` (string): Format type ('simple', 'enhanced', 'creative')
  - `options` (object, optional): Format-specific options
- **Returns**: `GreetingResult` object
- **Throws**: `Error` if format is not supported

#### `batchGreeting(greetingConfigs)`

Generate multiple greetings at once.

- **Parameters**:
  - `greetingConfigs` (Array): Array of `{format, options}` objects
- **Returns**: Array of `GreetingResult` objects

### Types

#### `GreetingResult`

```typescript
{
  message: string;        // The greeting message
  format: string;         // Format type used
  timestamp: Date;        // When greeting was created
  metadata?: {            // Optional metadata
    recipient?: string;
    formal?: boolean;
    style?: string;
    timeOfDay?: string;
    hasRecipient?: boolean;
  }
}
```

## Design Principles

### SOLID Principles

- **Single Responsibility**: Each function has one clear purpose
- **Open/Closed**: Easy to extend with new formats via factory
- **Liskov Substitution**: All greeting functions return same interface
- **Interface Segregation**: Clean, focused function signatures
- **Dependency Inversion**: No tight coupling to implementations

### Code Quality

- **DRY**: Reusable functions, no duplication
- **KISS**: Simple, straightforward implementations
- **Error Handling**: Proper validation and user-friendly errors
- **Documentation**: Comprehensive JSDoc comments
- **Type Safety**: JSDoc type definitions

## Testing

The module is designed to be easily testable with unit tests:

```javascript
const assert = require('assert');
const { simpleGreeting } = require('./src/greeting');

// Test basic functionality
const result = simpleGreeting();
assert.strictEqual(result.message, 'hello');
assert.strictEqual(result.format, 'simple');
assert(result.timestamp instanceof Date);
```

See `/tests/greeting/` directory for complete test suite.

## Performance Considerations

- **Lightweight**: No heavy dependencies
- **Fast**: Minimal computation overhead
- **Batch-friendly**: Efficient batch processing support
- **Memory-efficient**: No unnecessary object retention

## Error Handling

All functions include proper error handling:

```javascript
try {
  const result = simpleGreeting(123); // Wrong type
} catch (error) {
  console.error(error.message); // 'Message must be a string'
}

try {
  const result = greetingFactory('invalid'); // Unknown format
} catch (error) {
  console.error(error.message); // Lists supported formats
}
```

## Extensibility

Adding new formats is straightforward:

```javascript
// 1. Create new greeting function
function customGreeting(options = {}) {
  return {
    message: 'Custom greeting',
    format: 'custom',
    timestamp: new Date()
  };
}

// 2. Add to factory map
const formatMap = {
  simple: simpleGreeting,
  enhanced: enhancedGreeting,
  creative: creativeGreeting,
  custom: customGreeting  // Add new format
};
```

## License

Part of agl-hostman infrastructure project.

## Maintainer

Coder Agent - Hive Mind Collective
