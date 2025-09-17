# ⛽ Gas Fee Subsidizer

> 🚀 A smart contract that subsidizes gas fees for users, teaching meta-transaction concepts on Stacks blockchain

## 📖 Overview

The Gas Fee Subsidizer is a Clarity smart contract that allows contract owners to deposit STX tokens into a subsidy pool and cover gas fees for registered users. This contract demonstrates meta-transaction patterns where a third party can sponsor transaction costs for end users.

## 🌟 Key Features

- 💰 **Subsidy Pool Management** - Owner can deposit/withdraw STX for gas subsidization
- 👥 **User Registration** - Whitelist users with customizable daily limits  
- 🎯 **Smart Subsidization** - Automatically calculates and applies appropriate subsidy amounts
- 📊 **Usage Tracking** - Monitor daily usage per user with automatic resets
- 🛡️ **Safety Controls** - Emergency pause, limits, and admin-only functions
- 📈 **Batch Processing** - Subsidize multiple users in a single transaction

## 🔧 Contract Functions

### Admin Functions

| Function | Description |
|----------|-------------|
| `deposit-subsidy-funds` | 💵 Add STX to the subsidy pool |
| `withdraw-subsidy-funds` | 🏦 Remove STX from the subsidy pool |
| `register-user` | ✅ Register user with custom daily limit |
| `register-user-default` | 📝 Register user with default daily limit |
| `update-user-daily-limit` | 🔄 Modify user's daily subsidy limit |
| `emergency-pause/unpause` | 🚨 Emergency contract controls |
| `set-default-daily-limit` | ⚙️ Update default daily limit |
| `set-max-single-subsidy` | 🎚️ Update maximum single subsidy amount |
| `deregister-user` | ❌ Remove user from whitelist |

### Core Functions

| Function | Description |
|----------|-------------|
| `subsidize-gas-fee` | ⛽ Subsidize gas fee for a specific user |
| `bulk-subsidize` | 📦 Subsidize multiple users at once |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-contract-info` | 📋 Get contract configuration and status |
| `get-user-profile` | 👤 Get user registration and usage data |
| `get-available-daily-subsidy` | 💡 Check remaining daily subsidy for user |
| `get-subsidization-record` | 📊 Get specific subsidization transaction |
| `is-user-registered` | ✔️ Check if user is registered |
| `get-subsidy-stats` | 📈 Get overall contract statistics |

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX for testing

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd Gas-Fee-Subsidizer

# Check contract syntax
clarinet check

# Run tests
clarinet test
```

## 💡 Usage Examples

### 1. Deploy and Setup

```clarity
;; Deploy contract (done automatically by Clarinet)

;; Deposit funds to subsidize gas fees
(contract-call? .Gas-fee-subsidizer deposit-subsidy-funds u10000000) ;; 10 STX
```

### 2. Register Users

```clarity
;; Register user with custom daily limit
(contract-call? .Gas-fee-subsidizer register-user 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE u1000000)

;; Register user with default daily limit
(contract-call? .Gas-fee-subsidizer register-user-default 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
```

### 3. Subsidize Gas Fees

```clarity
;; Subsidize gas for a single user
(contract-call? .Gas-fee-subsidizer subsidize-gas-fee 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE u50000)

;; Bulk subsidize for multiple users
(contract-call? .Gas-fee-subsidizer bulk-subsidize 
  (list 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE 'ST2HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
  (list u50000 u75000)
)
```

### 4. Monitor Usage

```clarity
;; Check contract information
(contract-call? .Gas-fee-subsidizer get-contract-info)

;; Check user profile
(contract-call? .Gas-fee-subsidizer get-user-profile 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)

;; Check available daily subsidy
(contract-call? .Gas-fee-subsidizer get-available-daily-subsidy 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
```

## ⚙️ Configuration

### Default Settings

- **Default Daily Limit**: 1,000,000 microSTX (1 STX)
- **Max Single Subsidy**: 500,000 microSTX (0.5 STX)  
- **Daily Reset**: Every 144 blocks (~24 hours)

### Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Only contract owner can call this function |
| u101 | `err-insufficient-balance` | Insufficient balance for operation |
| u102 | `err-user-not-registered` | User is not registered for subsidization |
| u103 | `err-subsidy-limit-exceeded` | Daily subsidy limit exceeded |
| u104 | `err-invalid-amount` | Invalid amount provided |
| u105 | `err-contract-paused` | Contract is currently paused |
| u106 | `err-user-already-registered` | User is already registered |
| u107 | `err-insufficient-subsidy-pool` | Not enough STX in subsidy pool |

## 🧪 Testing

Run the test suite to verify contract functionality:

```bash
clarinet test
```

## 🔐 Security Features

- ✅ **Owner-only Admin Functions** - Critical functions restricted to contract deployer
- ✅ **Daily Usage Limits** - Prevents abuse with automatic daily resets
- ✅ **Maximum Subsidy Caps** - Limits maximum subsidy per transaction
- ✅ **Emergency Pause** - Contract can be paused in emergencies
- ✅ **Input Validation** - All inputs validated before processing

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with [Clarity](https://docs.stacks.co/clarity/) smart contract language
- Powered by [Stacks Blockchain](https://www.stacks.co/)
- Developed using [Clarinet](https://github.com/hirosystems/clarinet)

---

*Made with ❤️ for the Stacks ecosystem*
