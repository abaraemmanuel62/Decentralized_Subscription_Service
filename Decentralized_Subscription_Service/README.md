# Decentralized Subscription Service

A blockchain-based protocol for recurring cryptocurrency payments with adjustable billing cycles and automatic execution.

## Overview

The Decentralized Subscription Service (DSS) is a smart contract protocol built on the Stacks blockchain that enables subscription-based payment models for decentralized applications. It allows service providers to establish recurring payment arrangements with subscribers, with configurable payment amounts and billing periods.

## Features

- **Subscription Management**
  - Create subscriptions with customizable payment terms
  - Adjust subscription amounts and billing periods
  - Toggle auto-renewal settings
  - Cancel subscriptions from either subscriber or provider side

- **Automated Payments**
  - First payment processed on subscription creation
  - Recurring payments triggered automatically at specified intervals
  - Batch processing capability for multiple subscriptions

- **Revenue Management**
  - Track total and pending revenue for service providers
  - Simple withdrawal mechanism for service providers

- **Flexible Configuration**
  - Customizable billing cycles (specified in blocks)
  - Optional metadata storage for subscription details
  - Comprehensive error handling

## Technology Stack

- **Smart Contract**: Written in Clarity programming language
- **Blockchain**: Deployed on the Stacks blockchain
- **Testing**: Vitest test suite for contract validation

## Contract Structure

The protocol consists of the following key components:

1. **Data Structures**
   - `subscriptions`: Main storage for subscription details
   - `provider-subscriptions`: Maps providers to their subscription IDs
   - `subscriber-subscriptions`: Maps subscribers to their subscription IDs
   - `provider-revenue`: Tracks earnings for service providers

2. **Public Functions**
   - `create-subscription`: Establish a new subscription agreement
   - `process-payment`: Execute payment for due subscriptions
   - `cancel-subscription`: Terminate an active subscription
   - `update-subscription-amount`: Modify the payment amount
   - `update-subscription-period`: Change the billing cycle
   - `toggle-auto-renew`: Control automatic renewal
   - `withdraw-earnings`: Allow providers to collect funds
   - `batch-process-payments`: Process multiple subscriptions at once

3. **Read-Only Functions**
   - `get-subscription`: Retrieve details for a specific subscription
   - `get-provider-subscriptions`: List all subscriptions for a provider
   - `get-subscriber-subscriptions`: List all subscriptions for a subscriber
   - `get-provider-revenue`: Retrieve revenue information
   - `check-subscription-status`: Check if payment is due

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development environment
- [Node.js](https://nodejs.org/) - Required for running tests

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/decentralized-subscription-service.git
   cd decentralized-subscription-service
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

### Testing

Run the test suite to verify contract functionality:

```bash
npm test
```

## Usage Examples

### Creating a Subscription

```clarity
(contract-call? .subscription-service create-subscription 
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG  ;; provider
  u1000                                        ;; amount (in microSTX)
  u144                                         ;; period (approximately 1 day in blocks)
  true                                         ;; auto-renew
  (some u"Premium Content Access")             ;; metadata
)
```

### Processing a Payment

```clarity
(contract-call? .subscription-service process-payment u1)  ;; subscription ID
```

### Canceling a Subscription

```clarity
(contract-call? .subscription-service cancel-subscription u1)  ;; subscription ID
```

## Security Considerations

- The contract implements proper access controls to ensure only authorized parties can modify subscriptions
- Error handling prevents invalid operations like zero payments or periods
- All monetary operations are atomic to prevent partial state changes

## Future Enhancements

- Multi-token support for payments beyond STX
- Tiered subscription models with different service levels
- Discounts for longer commitment periods
- Integration with DAO governance for protocol updates

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request