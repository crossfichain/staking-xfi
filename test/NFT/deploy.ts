import { ethers } from "hardhat"
import {expect} from 'chai'

describe.only('NFT', function() {
    it('deploys and mints', async () => {
        const NFT = await ethers.getContractFactory('NFT')
        
        const baseURI = 'ipfs://bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna/'
        const name = 'PudgyPenguins'
        const symbol = 'PPG'

        const nft = await NFT.deploy(baseURI, name, symbol)

        expect(await nft.name()).to.be.eq(name)
        expect(await nft.symbol()).to.be.eq(symbol)
        expect(await nft.tokenURI(0)).to.be.eq(baseURI + 0)
        expect(await nft.tokenURI(9)).to.be.eq(baseURI + 9)

        await nft.mint()
        expect(await nft.tokenURI(10)).to.be.eq(baseURI + 10)
    })
})