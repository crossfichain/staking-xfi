import { time } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { getStakingContractsWithStakersAndRewards } from './_.fixtures'
import { ethers } from 'hardhat'
import { expect } from 'chai'
import { expectUpdateRewardToBeCalled } from './updateReward'

export const getReward = function () {
	/* --- Units --- */

	it.skip('non-reentrant')

	it('calls updateReward() modifier with msg.sender as argument', async function () {
		const { signers, staking } = await getStakingContractsWithStakersAndRewards()

		/* --- Setup rewards --- */

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		await staking.notifyRewardAmount(rewards)

		await time.increase(rewardsDuration)

		/* --- Function call --- */

		const call = () => staking.connect(signers[1]).getReward()

		/* --- Assert --- */

		await expectUpdateRewardToBeCalled(call, signers[1], staking, signers.slice(2, 4))
	})

	it('returns no rewards if there is none for user', async function () {
		const { signers, staking } = await getStakingContractsWithStakersAndRewards()

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		expect(await staking.earned(signers[9].address)).to.be.eq(0)
		await staking.notifyRewardAmount(rewards)

		await time.increase(rewardsDuration)

		const tx = staking.connect(signers[9]).getReward()
		await expect(tx).not.to.emit(staking, 'RewardPaid')
	})

	it('makes rewards = 0', async function () {
		const { signers, staking } = await getStakingContractsWithStakersAndRewards()

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		await staking.notifyRewardAmount(rewards)

		await time.increase(rewardsDuration)

		// Called to update 'rewards' mapping
		await staking.connect(signers[1]).getReward()

		const rewardsForUserAfterGetReward = await staking.rewards(signers[1].address)
		expect(rewardsForUserAfterGetReward).to.be.eq(0)
	})

	it('makes transfer', async function () {
		const { staking, signers } = await getStakingContractsWithStakersAndRewards()

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		await staking.notifyRewardAmount(rewards)
		await time.increase(rewardsDuration)

		const earned = await staking.earned(signers[1].address)

		const tx = staking.connect(signers[1]).getReward()

		await expect(tx).to.changeEtherBalances([signers[1], staking], [earned, -earned])
	})

	it('emits event RewardPaid', async function () {
		const { staking, signers } = await getStakingContractsWithStakersAndRewards()

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		await staking.notifyRewardAmount(rewards)
		await time.increase(rewardsDuration)

		const earned = await staking.earned(signers[1].address)

		const tx = staking.connect(signers[1]).getReward()
		await expect(tx).to.emit(staking, 'RewardPaid').withArgs(signers[1].address, earned)
	})

	/* --- Scenarios --- */

	it('rewards are distributed fairly in complex situation', async function () {
		const { signers, staking, stakingToken } = await getStakingContractsWithStakersAndRewards()

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		await staking.notifyRewardAmount(rewards)

		/* --- 1/3 of rewards duration --- */

		/*
		let stakeAmount1Staker = 1
		let stakeAmount2Staker = 2
		let stakeAmount3Staker = 3
		*/

		await time.increase(rewardsDuration / 3n)

		/* --- 2/3 of rewards duration --- */

		/*
		let stakeAmount1Staker = 2
		let stakeAmount2Staker = 1
		let stakeAmount3Staker = 5
		*/

		await staking.connect(signers[1]).stake(ethers.parseEther('1'))
		await staking.connect(signers[2]).withdraw(ethers.parseEther('1'))
		await staking.connect(signers[3]).stake(ethers.parseEther('2'))

		await time.increase(rewardsDuration / 3n)

		/* --- 3/3 of rewards duration --- */

		/*
		let stakeAmount1Staker = 3
		let stakeAmount2Staker = 4
		let stakeAmount3Staker = 3
		*/

		await staking.connect(signers[1]).stake(ethers.parseEther('1'))
		await staking.connect(signers[2]).stake(ethers.parseEther('3'))
		await staking.connect(signers[3]).withdraw(ethers.parseEther('2'))

		await time.increase(rewardsDuration / 3n)

		/* --- Rewards finished - assert state --- */

		const periodFinish = await staking.periodFinish()
		expect(await time.latest()).to.be.greaterThanOrEqual(periodFinish)

		const fairRewardFor1Staker =
			(BigInt(100e18) * 1n) / 6n / 3n + (BigInt(100e18) * 2n) / 8n / 3n + (BigInt(100e18) * 3n) / 10n / 3n

		const fairRewardFor2Staker =
			(BigInt(100e18) * 2n) / 6n / 3n + (BigInt(100e18) * 1n) / 8n / 3n + (BigInt(100e18) * 4n) / 10n / 3n

		const fairRewardFor3Staker =
			(BigInt(100e18) * 3n) / 6n / 3n + (BigInt(100e18) * 5n) / 8n / 3n + (BigInt(100e18) * 3n) / 10n / 3n

		// console.log('Fair Reward For 1 Staker', fairRewardFor1Staker)
		// console.log('Fair Reward For 2 Staker', fairRewardFor2Staker)
		// console.log('Fair Reward For 3 Staker', fairRewardFor3Staker)

		// const initialBalance1 = await ethers.provider.getBalance(signers[1])
		// const initialBalance2 = await ethers.provider.getBalance(signers[2])
		// const initialBalance3 = await ethers.provider.getBalance(signers[3])
		const reward1Staker = await staking.earned(signers[1])
		const reward2Staker = await staking.earned(signers[2])
		const reward3Staker = await staking.earned(signers[3])

		await staking.connect(signers[1]).getReward()
		await staking.connect(signers[2]).getReward()
		await staking.connect(signers[3]).getReward()

		// const reward1Staker = await ethers.provider.getBalance(signers[1])
		// const reward2Staker = await ethers.provider.getBalance(signers[2])
		// const reward3Staker = await ethers.provider.getBalance(signers[3])

		// console.log('Actual Reward For 1 Staker', reward1Staker)
		// console.log('Actual Reward For 2 Staker', reward2Staker)
		// console.log('Actual Reward For 3 Staker', reward3Staker)

		// Precision of reward calculation in contract is about 0.0001%
		const precision = 1000000n

		expect(reward1Staker).to.be.within(
			fairRewardFor1Staker - fairRewardFor1Staker / precision,
			fairRewardFor1Staker + fairRewardFor1Staker / precision
		)

		expect(reward2Staker).to.be.within(
			fairRewardFor2Staker - fairRewardFor2Staker / precision,
			fairRewardFor2Staker + fairRewardFor2Staker / precision
		)

		expect(reward3Staker).to.be.within(
			fairRewardFor3Staker - fairRewardFor3Staker / precision,
			fairRewardFor3Staker + fairRewardFor3Staker / precision
		)

		/*
					Notes on distribution calculation
					100000000000000000000 - rewards that meant to be distributed
					99999999999999359968  - actually distributed rewards
					640032 wei of rewardToken left undistributed due to calculation errors
					Better to have calculation error and rounding up that decrease rewards for users
					to be sure that's rewards on contract will be enough to distribute to all users
					*/
		const rewardBalanceOfContract = await ethers.provider.getBalance(staking)
		expect(rewardBalanceOfContract).to.be.lessThanOrEqual(BigInt(1e8))

		// Extremely precise for that amount of calculations with division
		expect(reward1Staker + reward2Staker + reward3Staker).to.be.within(99999999999000000000n, BigInt(100e18))
	})

	it('double withdraw of rewards will not get user more than he should get', async function () {
		const { signers, staking } = await getStakingContractsWithStakersAndRewards()

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		await staking.notifyRewardAmount(rewards)

		await time.increase(rewardsDuration)

		// Called to update 'rewards' mapping
		await staking.connect(signers[1]).getReward()
		const balanceBefore = await ethers.provider.getBalance(signers[1])
		// await staking.connect(signers[1]).getReward()

		// Rewards must be already updated, so earned() must return 0
		await staking.connect(signers[1]).getReward()
		const balanceAfter = await ethers.provider.getBalance(signers[1])

		expect(balanceBefore).to.be.eq(balanceAfter)

		// expect(await ethers.provider.getBalance(signers[9])).to.be.eq(0)
	})

	it('being called right after stake returns no or almost no rewards (depends on time passed)', async function () {
		const { signers, staking } = await getStakingContractsWithStakersAndRewards()

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		await staking.notifyRewardAmount(rewards)

		await time.increase(rewardsDuration)

		// Called to update 'rewards' mapping
		await staking.connect(signers[1]).getReward()
		const balanceBefore = await ethers.provider.getBalance(signers[1])
		// await staking.connect(signers[1]).getReward()

		// Rewards must be already updated, so earned() must return 0
		await staking.connect(signers[1]).getReward()
		const balanceAfter = await ethers.provider.getBalance(signers[1])

		expect(balanceBefore).to.be.eq(balanceAfter)

		// expect(await ethers.provider.getBalance(signers[9])).to.be.eq(0)
	})

	it('after all reward has been claimed contract should be empty', async function () {
		const { signers, staking } = await getStakingContractsWithStakersAndRewards()

		const rewards = await ethers.provider.getBalance(staking)
		const rewardsDuration = await staking.rewardsDuration()

		await staking.notifyRewardAmount(rewards)

		await time.increase(rewardsDuration)

		// Called to collect all reward tokens
		await staking.connect(signers[1]).getReward()
		await staking.connect(signers[2]).getReward()
		await staking.connect(signers[3]).getReward()

		const balance = await ethers.provider.getBalance(staking)

		expect(balance).to.be.approximately(0, 1e8)

		// expect(await ethers.provider.getBalance(signers[9])).to.be.eq(0)
	})
}
