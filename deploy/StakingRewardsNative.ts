import { ethers } from 'hardhat'
import { wait } from '../scripts/wait'
import { verify } from '../scripts/verify'
import { StakingRewardsNative__factory } from '../typechain-types'

async function main() {
	const Staking = (await ethers.getContractFactory('StakingRewardsNative')) as StakingRewardsNative__factory

	const stakingTokenAddr = '0xaE8E45b0f48b274F4d59dE325017A7c60B5d11Be'

	const name = 'Staked LP-XUSD/USDT'
	const symbol = 'SLP-XUSD/USDT'
	const staking = await Staking.deploy(name, symbol, stakingTokenAddr)

	await staking.waitForDeployment()

	console.log('Staking deployed at:', await staking.getAddress())

	await wait(30)

	await verify(await staking.getAddress(), [name, symbol, stakingTokenAddr])
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error)
		process.exit(1)
	})
