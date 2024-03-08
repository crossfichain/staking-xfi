import { ethers } from 'hardhat'
import { UniswapInterfaceMulticall } from '../typechain-types'
import { UniswapInterfaceMulticall__factory } from '../typechain-types/factories/contracts/Multicall.sol'
import { wait } from '../scripts/wait'
import { verify } from '../scripts/verify'

async function main() {
	// const Multicall = await ethers.getContractFactory('UniswapInterfaceMulticall') as UniswapInterfaceMulticall__factory

	// const multicall = await Multicall.deploy()

	// await multicall.waitForDeployment()
	// const multicallAddr = await multicall.getAddress()
	
	const multicallAddr = '0x14626592571be0F4308f0D5027C07Ec712D5D04D'

	console.log('Multicall deployed at:', multicallAddr)
	// await wait(30)

	await verify(multicallAddr, [])
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error)
		process.exit(1)
	})
