# XBorg Launchpad

XBorg Launchpad will be used to allow projects to raise funds from the XBorg community. Selected projects will be able to define the different tiers, giving people minimum and maximum allocations based on criteria and to open a fundraise to the public.

Furthermore, after TGE, projects will be able to distribute their tokens through a dedicated contract allowing people to claim their token following a cliff-linear vesting.

The first use-case of the contracts will be for the XBorg (XBG) token. A presale will run through the Vault contract and the tokens will be distributed through the TokenDistribution contract. 

Note that contracts are designed and engineered with the idea of being reusable for multiple raises and distributions but that a new instance will be deployed every time.

## Installation

```
yarn install
forge install
forge build
```

## Contracts

The launchpad is composed of three contracts: the `Vault`, the `TierManager` and the `TokenDistribution`.

### contracts/Vault.sol

This contract is in charge of managing the different fundraises' vaults.

### contracts/TierManager.sol

This contract manages the different tiers allowing users to invest into a specific fundraise.

### contracts/TokenDistribution.sol

This contract is to set up a stream of tokens that are vested. Each stream is a cliff vesting (linear).

### contracts/XBorgToken.sol

This contract implements the XBorg (XBG) token.

### Roles

- `DEFAULT_ADMIN_ROLE`: can grant and revoke a role as well as upgrade the contract.
- `MANAGER_ROLE`: can perform administrative actions.

## Tests

A full suite of tests is written in Solidity and available in the `test/` folder.

To run the tests: `forge test`.

### Coverage

For the coverage: `forge coverage`.

This is the output:

```
| File                                    | % Lines           | % Statements      | % Branches       | % Funcs         |
|-----------------------------------------|-------------------|-------------------|------------------|-----------------|
| src/TierManager.sol                     | 100.00% (40/40)   | 100.00% (43/43)   | 83.33% (15/18)   | 100.00% (12/12) |
| src/TokenDistribution.sol               | 100.00% (69/69)   | 100.00% (90/90)   | 100.00% (34/34)  | 100.00% (21/21) |
| src/Vault.sol                           | 100.00% (103/103) | 100.00% (111/111) | 100.00% (78/78)  | 100.00% (22/22) |

```

Foundry doesn't allow to exclude contracts yet, so it will also return test contracts. See [foundry#2988](https://github.com/foundry-rs/foundry/issues/2988).

Also, it doesn't hit on three branches:

```
Uncovered for src/TierManager.sol:
- Branch (branch: 3, path: 0) (location: source ID 73, line 99, chars 3864-3981, hits: 0)
- Branch (branch: 4, path: 0) (location: source ID 73, line 101, chars 3987-4106, hits: 0)
- Branch (branch: 5, path: 0) (location: source ID 73, line 103, chars 4112-4269, hits: 0)
```

This is also a limitation of foundry, from the tests in `test/TierManager.GetAllocation.t.sol`, we confirm that the branches were hit. See [foundry#3497](https://github.com/foundry-rs/foundry/issues/3497).

### Upgrades

To check if a contract is upgrade safe:

```
forge clean
forge build
yarn validate-upgrade
```

## Deployment

Deployment scripts are available in `scripts/`.

To deploy a contract:

1. Set the `initialize()` variables inside the `constructor()` method of the deployer contract.
2. Run:
```
forge script scripts/<contract.sol> --rpc-url <rpc> --private-key <deployer private key> --etherscan-api-key <etherscan-api-key> --verify --broadcast
```

## Links

- XBorg: [xborg.com](xborg.com)

