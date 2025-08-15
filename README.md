# TimeVault

**Decentralized Temporal Access Control for Premium Gaming Experiences**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Stacks](https://img.shields.io/badge/Stacks-Blockchain-blue)](https://stacks.co)
[![Clarity](https://img.shields.io/badge/Smart%20Contract-Clarity-purple)](https://clarity-lang.org)

## Overview

TimeVault revolutionizes digital entertainment through blockchain-native time banking. Players mint temporal credits that unlock exclusive gaming sessions, with each credit representing verified blockchain time units. The protocol ensures fair play distribution, prevents time manipulation, and creates a sustainable economy where premium gaming time becomes a tradeable digital asset backed by cryptographic proof of temporal commitment.

## Architecture

### Core Components

- **Temporal Credit System**: Blockchain-verified time units for premium access
- **Tier-Based Access Control**: Multiple subscription tiers with different rates and benefits
- **Session Management**: Secure session tracking with automatic expiration
- **Administrative Controls**: Owner-managed tier configuration and contract governance

### Key Features

- ✅ **Time-Based Access Control**: Sessions based on Stacks block height
- ✅ **Multi-Tier Subscription Model**: Flexible pricing and duration options
- ✅ **Secure Payment Processing**: STX transfers with overflow protection
- ✅ **Session Extension**: Extend active sessions with prorated pricing
- ✅ **Auto-Renewal Support**: Optional automatic session renewal
- ✅ **Administrative Tools**: Dynamic tier management and ownership transfer

## Contract Specifications

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 200 | `ERR_UNAUTHORIZED` | Caller lacks required permissions |
| 201 | `ERR_INVALID_TIME_DURATION` | Invalid session duration provided |
| 202 | `ERR_INSUFFICIENT_BALANCE` | Insufficient STX balance for operation |
| 203 | `ERR_ACTIVE_SESSION_EXISTS` | User already has an active session |
| 204 | `ERR_NO_ACTIVE_SESSION` | No active session found for user |
| 205 | `ERR_SESSION_EXPIRED` | Session has expired |
| 206 | `ERR_INVALID_TIER_CONFIG` | Invalid tier configuration |
| 207 | `ERR_MALFORMED_INPUT` | Malformed input parameters |
| 208 | `ERR_ARITHMETIC_OVERFLOW` | Arithmetic operation overflow detected |

### Security Constraints

- **Maximum Tier Limit**: 100 tiers
- **Block Cost Range**: 1 - 1,000,000 STX per block
- **Session Length Limit**: ~10 years (525,600 blocks)
- **Identifier Length**: 64 ASCII characters maximum

### Data Structures

#### Access Tiers

```clarity
{
  tier-name: (string-ascii 64),
  block-rate: uint,
  min-session-blocks: uint,
  max-session-blocks: uint,
  tier-active: bool
}
```

#### User Sessions

```clarity
{
  user-id: uint,
  current-tier: uint,
  session-start: uint,
  session-end: uint,
  renewal-enabled: bool,
  lifetime-expenditure: uint
}
```

## API Reference

### Read-Only Functions

#### `fetch-tier-details`

```clarity
(fetch-tier-details (tier-id uint)) -> (optional tier-data)
```

Retrieves configuration details for a specific tier.

#### `fetch-user-session`

```clarity
(fetch-user-session (user principal)) -> (optional session-data)
```

Gets the current session information for a user.

#### `verify-active-session`

```clarity
(verify-active-session (user principal)) -> bool
```

Checks if a user has an active, non-expired session.

#### `calculate-remaining-blocks`

```clarity
(calculate-remaining-blocks (user principal)) -> (optional uint)
```

Returns the number of blocks remaining in a user's session.

#### `compute-session-cost`

```clarity
(compute-session-cost (tier-id uint) (block-count uint)) -> (response uint uint)
```

Calculates the STX cost for a session of specified duration and tier.

### Public Functions

#### `initialize-session`

```clarity
(initialize-session (tier-id uint) (session-blocks uint) (auto-renewal bool)) -> (response uint uint)
```

Creates a new gaming session with specified parameters.

**Parameters:**

- `tier-id`: The subscription tier (1-100)
- `session-blocks`: Duration in Stacks blocks
- `auto-renewal`: Enable automatic renewal when session expires

**Returns:** Unique user ID for the session

#### `extend-session-duration`

```clarity
(extend-session-duration (additional-blocks uint)) -> (response uint uint)
```

Extends an active session by the specified number of blocks.

#### `terminate-session`

```clarity
(terminate-session) -> (response bool uint)
```

Immediately terminates the caller's active session.

#### `toggle-renewal-setting`

```clarity
(toggle-renewal-setting) -> (response bool uint)
```

Toggles the auto-renewal setting for the caller's session.

### Administrative Functions

#### `deploy-new-tier`

```clarity
(deploy-new-tier (tier-name (string-ascii 64)) (block-rate uint) (min-blocks uint) (max-blocks uint)) -> (response uint uint)
```

Creates a new subscription tier (owner only).

#### `modify-tier-configuration`

```clarity
(modify-tier-configuration (tier-id uint) (tier-name (string-ascii 64)) (block-rate uint) (min-blocks uint) (max-blocks uint) (active-status bool)) -> (response bool uint)
```

Updates an existing tier's configuration (owner only).

#### `transfer-ownership`

```clarity
(transfer-ownership (new-owner principal)) -> (response bool uint)
```

Transfers contract ownership to a new principal (owner only).

## Default Tier Configuration

The contract deploys with two pre-configured tiers:

### Standard Access (Tier 1)

- **Rate**: 12 STX per block
- **Minimum Duration**: 4,320 blocks (~30 days)
- **Maximum Duration**: 52,560 blocks (~365 days)
- **Status**: Active

### Premium Access (Tier 2)

- **Rate**: 25 STX per block
- **Minimum Duration**: 4,320 blocks (~30 days)
- **Maximum Duration**: 52,560 blocks (~365 days)
- **Status**: Active

## Usage Examples

### Initialize a Gaming Session

```clarity
;; Start a 30-day premium session with auto-renewal
(contract-call? .time-vault initialize-session u2 u4320 true)
```

### Check Session Status

```clarity
;; Verify if user has active session
(contract-call? .time-vault verify-active-session 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Get remaining blocks
(contract-call? .time-vault calculate-remaining-blocks 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Extend Session

```clarity
;; Extend session by 7 days (1008 blocks)
(contract-call? .time-vault extend-session-duration u1008)
```

## Development Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) CLI
- Node.js 16+ for testing
- Stacks Wallet for deployment

### Installation

```bash
# Clone the repository
git clone https://github.com/piro-papa/time-vault.git
cd time-vault

# Install dependencies
npm install

# Check contract syntax
clarinet check
```

### Testing

```bash
# Run contract tests
npm test

# Run specific test file
npx vitest tests/time-vault.test.ts
```

### Deployment

#### Testnet Deployment

```bash
# Deploy to Stacks testnet
clarinet deploy --testnet
```

#### Mainnet Deployment

```bash
# Deploy to Stacks mainnet
clarinet deploy --mainnet
```

## Security Considerations

### Arithmetic Safety

- All multiplication and addition operations use overflow-safe functions
- Division by zero protection in cost calculations
- Input validation for all user-provided parameters

### Access Control

- Owner-only functions protected by principal verification
- Session isolation prevents cross-user interference
- Immutable session history in registry

### Economic Security

- Maximum cost limits prevent excessive payments
- Session duration bounds prevent abuse
- Secure STX transfer handling

## Gas Optimization

The contract implements several gas optimization strategies:

- **Batch Operations**: Registry updates combined with session modifications
- **Efficient Storage**: Optimized data structure layouts
- **Lazy Evaluation**: Conditional validation to minimize computation
- **Secure Arithmetic**: Overflow protection without excessive overhead

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Clarity best practices and naming conventions
- Add comprehensive tests for new functionality
- Update documentation for API changes
- Ensure gas efficiency in contract modifications

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on the [Stacks](https://stacks.co) blockchain
- Powered by [Clarity](https://clarity-lang.org) smart contracts
- Testing framework provided by [Clarinet](https://github.com/hirosystems/clarinet)

---

*TimeVault - Revolutionizing digital entertainment through blockchain-native temporal access control.*
