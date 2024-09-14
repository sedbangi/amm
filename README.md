# Naik/Lewandro AMM

## Documentation
For sequence diagram please install plantuml extension in VSCode, java runtime under ubuntu using


```
sudo apt install default-jre
```

## Statistics
Can be found under the folder *stats*


## amm
Solidity source code based on 

```
https://github.com/haardikk21/take-profits-hook
```

Get foundry

```
curl -L https://foundry.paradigm.xyz | bash
```

run

```
foundryup
```

### Usage

#### Initialize a new foundry project
```
forge init damm
```

#### Install v4-periphery
```
cd damm
forge install Uniswap/v4-periphery
```

#### Place remappings
```
forge remappings > remappings.txt
```

#### Remove default Counter.sol files
```
rm ./**/Counter*.sol
```

#### Set env variable
```
export FORGE_SNAPSHOT_CHECK=true
```

#### Change PoolSwapTest line 66 for sennding sender address in hookdata
```
// BalanceDelta delta = manager.swap(data.key, data.params, data.hookData);
BalanceDelta delta = manager.swap(data.key, data.params, abi.encode(NewHookData(data.hookData, address(data.sender))));
```

#### Build

```shell
$ forge build
```

#### Test

```shell
$ forge test
```