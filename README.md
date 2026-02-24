# Decentralized Insurance Policy Smart Contract

A decentralized insurance policy management system that enables transparent policy creation, premium payments, claim processing, and approval logic.

The system removes intermediaries and ensures transparent claim verification.

## Architecture

Roles:
- Admin
- Policy Holder
- Verifier(insurer)

## Features

### Policy Creation
- insurer creates insurance policies
- Defines coverage, duration, premium

### Premium Payment Tracking
- Records payment history
- Ensures active policy validation

### Claim Submission
- Policy holder submits claim
- isApproved and isReceived to track status

### Claim Verification
- Only authorized verifier can approve
- Prevents duplicate claims

### Event Emission
- PolicyCreated
- ClaimSubmitted
- ClaimApproved

## 🧪 Testing

Includes:
- Policy lifecycle testing
- Claim submission edge cases
- Unauthorized access attempts
- Event emission validation
- Revert testing

## Tech Stack

- Solidity
- Hardhat
- Ethers.js
- Chai

## Run Locally

npm install
npx hardhat compile
npx hardhat test
