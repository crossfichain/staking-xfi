import { fixtures } from './_.fixtures'

import { earned } from './earned'
import { exit } from './exit'
import { getReward } from './getReward'
import { getRewardForDuration } from './getRewardForDuration'
import { lastTimeRewardApplicable } from './lastTimeRewardApplicable'
import { notifyRewardAmount } from './notifyRewardAmount'
import { rewardPerToken } from './rewardPerToken'
import { stake } from './stake'
import { updateReward } from './updateReward'
import { withdraw } from './withdraw'

describe.only('StakingRewardsNative', function () {
	/* --- Fixtures --- */

	describe('fixtures', fixtures)

	/* --- Basic StakingRewards --- */

	/* --- View functions --- */

	describe('rewardPerToken', rewardPerToken)
	describe('earned', earned)

	describe('getRewardForDuration', getRewardForDuration)
	describe('lastTimeRewardApplicable', lastTimeRewardApplicable)

	/* --- Mutable functions --- */

	describe('stake', stake)
	describe('withdraw', withdraw)
	describe('getReward', getReward)
	describe('exit', exit)
	describe('notifyRewardAmount', notifyRewardAmount)

	/* --- Modifier --- */

	describe('updateReward', updateReward)

	/* --- Modified ERC20 Logic --- */

	describe('totalSupply', async function () {
		// changes on stake/unstake
	})
	describe('transfer', async function () {
		// non-trasferable
	})
	describe('transferFrom', async function () {})
	describe('allowance', async function () {
		// non-trasferable
	})
})
