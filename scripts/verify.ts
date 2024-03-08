import { HardhatRuntimeEnvironment } from 'hardhat/types'
import hardhat from 'hardhat'

export async function verify(address: string, constructorArguments: any[]) {
	await hardhat.run('verify:verify', {
		address,
		constructorArguments,
	})
}
