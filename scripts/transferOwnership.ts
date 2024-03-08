import { ethers } from 'hardhat'
import { ERC20Mintable, Staking } from '../typechain-types'

async function main() {
	const ERC20 = await ethers.getContractFactory('ERC20Mintable')

	const tokenAddr = '0x4DC2041666Dd77dA586F0F22DE785d008c6448C1'
	const newOwner = '0x5826279b07c067e007405Bb3c0f48A1451904368'

	const token = ERC20.attach(tokenAddr) as ERC20Mintable

	await token.transferOwnership(newOwner)

	console.log('Transferred ownership')
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error)
		process.exit(1)
	})
