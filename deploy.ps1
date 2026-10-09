# ===== One-click local deployment of Uniswap V2 (core + periphery) =====
# Prereq: run `anvil` in another terminal (default http://127.0.0.1:8545)
# Run:    powershell -ExecutionPolicy Bypass -File .\deploy.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$rpc    = 'http://127.0.0.1:8545'
$pk     = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' # anvil account #0 key (LOCAL TEST ONLY)
$acct   = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
$one    = '1000000000000000000'              # 1e18
$supply = '1000000000000000000000000000'     # 1e27

function ParseAddr([string]$s) {
  $m = [regex]::Match($s, 'Deployed to:\s*(0x[0-9a-fA-F]{40})')
  if (-not $m.Success) { throw "deploy failed, output:`n$s" }
  $m.Groups[1].Value
}

Write-Host '==> deploy Factory / WETH9 / Router02 / 2 test tokens'
$factory = ParseAddr (forge create --broadcast --rpc-url $rpc --private-key $pk 'lib/v2-core/contracts/UniswapV2Factory.sol:UniswapV2Factory' --constructor-args $acct 2>&1 | Out-String)
$weth    = ParseAddr (forge create --broadcast --rpc-url $rpc --private-key $pk 'lib/v2-periphery/contracts/test/WETH9.sol:WETH9' 2>&1 | Out-String)
$router  = ParseAddr (forge create --broadcast --rpc-url $rpc --private-key $pk 'lib/v2-periphery/contracts/UniswapV2Router02.sol:UniswapV2Router02' --constructor-args $factory $weth 2>&1 | Out-String)
$tokenA  = ParseAddr (forge create --broadcast --rpc-url $rpc --private-key $pk 'lib/v2-periphery/contracts/test/ERC20.sol:ERC20' --constructor-args $supply 2>&1 | Out-String)
$tokenB  = ParseAddr (forge create --broadcast --rpc-url $rpc --private-key $pk 'lib/v2-periphery/contracts/test/ERC20.sol:ERC20' --constructor-args $supply 2>&1 | Out-String)

Write-Host '==> createPair'
cast send --rpc-url $rpc --private-key $pk $factory 'createPair(address,address)' $tokenA $tokenB | Out-Null
$pair = cast call --rpc-url $rpc $factory 'getPair(address,address)(address)' $tokenA $tokenB

Write-Host '==> approve + addLiquidity 1:1'
cast send --rpc-url $rpc --private-key $pk $tokenA 'approve(address,uint256)' $router 1000000000000000000000 | Out-Null
cast send --rpc-url $rpc --private-key $pk $tokenB 'approve(address,uint256)' $router 1000000000000000000000 | Out-Null
cast send --rpc-url $rpc --private-key $pk $router 'addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)' $tokenA $tokenB $one $one 0 0 $acct 99999999999 | Out-Null

Write-Host '==> swap 0.001 TokenA -> TokenB'
cast send --rpc-url $rpc --private-key $pk $router 'swapExactTokensForTokens(uint256,uint256,address[],address,uint256)' 1000000000000000 0 "[$tokenA,$tokenB]" $acct 99999999999 | Out-Null

Write-Host ''
Write-Host '================== RESULT =================='
Write-Host "Factory : $factory"
Write-Host "WETH9   : $weth"
Write-Host "Router02: $router"
Write-Host "TokenA  : $tokenA"
Write-Host "TokenB  : $tokenB"
Write-Host "Pair    : $pair"
Write-Host 'reserves (reserve0, reserve1, blockTimestampLast):'
cast call --rpc-url $rpc $pair 'getReserves()(uint112,uint112,uint32)'
