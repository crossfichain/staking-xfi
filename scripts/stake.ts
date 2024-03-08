import { ethers } from 'hardhat'
import { ERC20Mintable, Staking } from '../typechain-types'

async function main() {
	const Staking = await ethers.getContractFactory('Staking')
	const LP = await ethers.getContractFactory('ERC20Mintable')
	const signers = await ethers.getSigners()
	const deployer = signers[0]
	console.log(deployer.address)

	const stakingTokenAddr = '0xB867C7a3e18deb63964AF56bF0770c20Fe4d80df'
	const stakingAddr = '0x1E1B4c52A752d80df92B0c96e8B706C065980eC9'

	const lp = LP.attach(stakingTokenAddr) as ERC20Mintable
	await lp.mint(deployer.address, BigInt(1e24))

	console.log('Minted LP')

	await lp.approve(stakingAddr, BigInt(1e24))

	console.log('Approved LP to staking')

	const staking = Staking.attach(stakingAddr) as Staking

	await staking.stake(BigInt(1e20))
	console.log('Staked tokens on contract')
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error)
		process.exit(1)
	})
