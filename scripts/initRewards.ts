import { ethers } from 'hardhat'
import { ERC20Mintable, Staking } from '../typechain-types'

async function main() {
	const Staking = await ethers.getContractFactory('Staking')
	const WETH = await ethers.getContractFactory('ERC20Mintable')

	const rewardsTokenAddr = '0x74f4B6c7F7F518202231b58CE6e8736DF6B50A81'
	const stakingAddr = '0x8D1dd64aC4306274585ad0BE302283A8D40a8383'

	const wethRewards = BigInt(1e20)
	const nativeRewards = BigInt(2e20)

	const weth = WETH.attach(rewardsTokenAddr) as ERC20Mintable
	await weth.mint(stakingAddr, wethRewards)

	console.log('Minted WETH')

	let tx = await weth.transfer(stakingAddr, wethRewards)
	await tx.wait()

	console.log('Send WETH')

	const staking = Staking.attach(stakingAddr) as Staking

	await staking.notifyTokenRewardAmount(wethRewards)
	console.log('Notified contract about Token rewards')

	await staking.notifyNativeRewardAmount(nativeRewards, { value: nativeRewards })
	console.log('Notified contract about Native rewards')

	console.log('Native rewards rate', await staking.nativeRewardRate())
	console.log('Token rewards rate', await staking.tokenRewardRate())
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error)
		process.exit(1)
	})
