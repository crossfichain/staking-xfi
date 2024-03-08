import { ethers } from 'hardhat'
import { wait } from '../scripts/wait'
import { verify } from '../scripts/verify'

async function main() {
	const Staking = await ethers.getContractFactory('Staking')

	const rewardsTokenAddr = '0x74f4B6c7F7F518202231b58CE6e8736DF6B50A81'
	const stakingTokenAddr = '0xF4Dc9dfDB41431A9C9b834239ece79fC311A0184'

	const staking = await Staking.deploy(
		'0xf58941E4258320D76BdAb72C5eD8d47c25604e94',
		rewardsTokenAddr,
		stakingTokenAddr,
		'Staked LP XFI',
		'sLPXFI'
	)

	await staking.waitForDeployment()

	console.log('Staking deployed at:', await staking.getAddress())

	await wait(30)

	await verify(await staking.getAddress(), [
		'0xf58941E4258320D76BdAb72C5eD8d47c25604e94',
		rewardsTokenAddr,
		stakingTokenAddr,
		'Staked LP XFI',
		'sLPXFI',
	])
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error)
		process.exit(1)
	})
