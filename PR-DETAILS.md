## Overview

This PR introduces the badge-manager smart contract, providing a complete solution for managing digital badges on the Stacks blockchain with transparent on-chain verification.

## Changes

### New Contract: badge-manager

A comprehensive badge management system featuring:

**Core Functionality**
- Badge type creation with metadata support
- Badge issuance to recipients with verification
- Badge revocation with audit trail
- Role-based access control system
- Platform-wide pause mechanism

**Data Structures**
- Badge types with name, description, and metadata URI
- Individual badge records tracking recipient, issuer, and status
- Authorization mapping for granular issuer permissions
- Administrator registry for privileged operations

**Access Control**
- Contract owner with full privileges
- Administrator role for platform management
- Authorized issuers per badge type
- Multi-level permission checks

**State Management**
- Badge lifecycle tracking (issued/revoked)
- Recipient badge ownership mapping
- Badge type issuance counters
- Revocation audit trail with timestamp and revoker

**Read Functions**
- Badge and badge type information retrieval
- Ownership verification
- Authorization status checks
- Platform state queries

## Technical Details

**Lines of Code:** 316
**Language:** Clarity
**Framework:** Clarinet

**Key Features:**
- No external dependencies or trait implementations
- Simple, clean architecture
- Comprehensive error handling
- Gas-efficient data structures

## Testing

Contract passes `clarinet check` with warnings only for unchecked data (standard for user inputs).

## Security

- All administrative functions protected by authorization checks
- Prevention of duplicate badge issuance per recipient per type
- Immutable record of all badge operations
- Safe revocation mechanism preserving history
