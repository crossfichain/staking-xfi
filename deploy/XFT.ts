import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { ERC20Mintable } from '../typechain-types'

export default async function (hre: HardhatRuntimeEnvironment, name: string, symbol: string): Promise<ERC20Mintable> {
	const ethers = hre.ethers
	const ERC20 = await ethers.getContractFactory('ERC20Mintable')

	const xft = await ERC20.deploy('XFT', 'XFT')

	await xft.waitForDeployment()

	console.log('XFT deployed at:', await xft.getAddress())

	return xft
}

// main().then(finishScript).catch(handleReject)
