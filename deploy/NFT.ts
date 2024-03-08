import { ethers } from 'hardhat'
import { wait } from '../scripts/wait'
import { verify } from '../scripts/verify'

async function main() {
	const NFT = await ethers.getContractFactory('NFT')

	const collections = {
		Pudgy: {
			baseURI: 'ipfs://bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna/',
			name: 'PudgyPenguins',
			symbol: 'PPG',
		},
		BAYC: {
			baseURI: 'ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/',
			name: 'BoredApeYachtClub',
			symbol: 'BAYC',
		},
		Doodles: {
			baseURI: 'ipfs://QmPMc4tcBsMqLRuCQtPmPe84bpSjrC3Ky7t3JWuHXYB4aS/',
			name: 'Doodles',
			symbol: 'DOODLE',
		},
	}

	const { baseURI, name, symbol } = collections.BAYC

	const nft = await NFT.deploy(baseURI, name, symbol)

	await nft.waitForDeployment()

	console.log('NFT deployed at:', await nft.getAddress())

	console.log('Waiting for contract indexing...')
	await wait(30)

	await verify(await nft.getAddress(), [baseURI, name, symbol])
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error)
		process.exit(1)
	})
