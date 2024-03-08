import { ethers } from 'hardhat'
import { NFT } from '../typechain-types'

const collections = {
	Doodles: '0xB867C7a3e18deb63964AF56bF0770c20Fe4d80df',
	PudgyPenguins: '0x74f4B6c7F7F518202231b58CE6e8736DF6B50A81',
	BAYC: '0xd2520Ff0B35B7bfaf15a271ccc5d3C55102BB886',
}

async function main() {
	const NFT = await ethers.getContractFactory('NFT')
	const [deployer] = await ethers.getSigners()
	const collectionAddr = collections.PudgyPenguins

	const nft = NFT.attach(collectionAddr) as NFT
	await nft.mint()

	const tokenId = 0
	const receiver = '0x79F9860d48ef9dDFaF3571281c033664de05E6f5'
	await nft.transferFrom(deployer.address, receiver, tokenId)

	console.log('Minted NFT')
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error)
		process.exit(1)
	})
