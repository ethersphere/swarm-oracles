const { expect } = require('chai');
const {
    BN,
    balance,
    time,
    expectEvent,
    expectRevert
  } = require("openzeppelin-test-helpers");

const MsgOracle = artifacts.require('MsgOracle')

contract('MsgOracle', function([owner, nonOwner]) {
  const InitialTTL = new BN(60)
  beforeEach(async function() {
    this.msgOracle = await MsgOracle.new(InitialTTL, {from: owner})
  })

  describe('deployment', function() {
    it('should have set initial TTL', async function() {
      expect(await this.msgOracle.TTL()).bignumber.to.be.equal(InitialTTL)
    })
    it('should emit a LogNewTTL event', function() {
      expectEvent.inConstruction(this.msgOracle, "LogNewTTL", {
        TTL: InitialTTL
      })
    })
  })

  describe('newTTL', function() {
    const newTTL = new BN(120)
    context('when owner is the caller', function() {
      const caller = owner
      context('When newTTL was last updated more than TTL seconds ago', function() {
        beforeEach(async function() {
          await time.increase(InitialTTL)
          const { logs } = await this.msgOracle.newTTL(newTTL, {from: caller})
          this.logs = logs
        })
        it('should have updated TTL', async function() {
          expect(await this.msgOracle.TTL()).bignumber.to.be.equal(newTTL)
        })
        it('should emit a LogNewTTL event', function() {
          expectEvent.inLogs(this.logs, 'LogNewTTL', {
            TTL: newTTL
          })
        })
      })
      context('When newTTL was last updated less than TTL seconds ago', async function() {
        it('reverts', async function() {
          const revertMsg = "MsgOracleOwner: TTL less than TTL seconds ago updated"
          await expectRevert(this.msgOracle.newTTL(newTTL, {from: caller}), revertMsg)
        })
      })
    })
    context('when owner is not the caller', async function() {
      const caller = nonOwner
      const revertMsg = "Ownable: caller is not the owner"
      it('reverts', async function() {
        await expectRevert(this.msgOracle.newTTL(newTTL, {from: caller}), revertMsg)
      })
    })
  })

  describe('setMsgPrice', function() {
    const msgType = web3.utils.fromAscii("mockMessage")
    const msgPrice = new BN(42)
    context('when owner is the caller', function() {
      const caller = owner
      context('when there is no pending TTL update', function() {
        context('when validFrom is at least TTL seconds in the future', async function() {
          beforeEach(async function() {
            const validFrom = (await time.latest()).add(InitialTTL)
            this.validFrom = validFrom
            const { logs } = await this.msgOracle.setMsgPrice(msgType, msgPrice, validFrom, {from: caller}) 
            this.logs = logs
          })
          it('should emit a LogSetMsgPrice event', function() {
            expectEvent.inLogs(this.logs, 'LogSetMsgPrice', {
              swarmMsg: web3.utils.padRight(msgType, 64),
              price: msgPrice,
              validFrom: this.validFrom
            })
          })
        })
        context('when validFrom is less than TTL seconds in the future', async function() {
          const validFrom = (await time.latest())
          const revertMsg = "MsgOracle: validFrom not oldTTL seconds in the future"
          it('reverts', async function() {
            await expectRevert(this.msgOracle.setMsgPrice(msgType, msgPrice, validFrom, {from: caller}), revertMsg)
          })
        })
      })
      context('when there is a TTL update', function() {
        const newTTL = new BN(120)
        beforeEach(async function() {
          await time.increase(InitialTTL)
          await this.msgOracle.newTTL(newTTL, {from: owner})
        })
        context('when the TTL update is pending', function() {
          context('when validFrom is more than the old TTL in the future', function() {
            beforeEach(async function() {
              const validFrom = (await time.latest()).add(InitialTTL)
              this.validFrom = validFrom
              const { logs } = await this.msgOracle.setMsgPrice(msgType, msgPrice, validFrom, {from: caller})
              this.logs = logs
            })
            it('should emit a LogSetMsgPrice event', function() {
              expectEvent.inLogs(this.logs, 'LogSetMsgPrice', {
                swarmMsg: web3.utils.padRight(msgType, 64),
                price: msgPrice,
                validFrom: this.validFrom
              })
            })
          })
          context('when TTL is less than the old TTL in the future', async function() {
            beforeEach(async function() {
              const validFrom = (await time.latest())
              this.validFrom = validFrom
            })
            const revertMsg = "MsgOracle: validFrom not oldTTL seconds in the future"
            it('reverts', async function() {
              await expectRevert(this.msgOracle.setMsgPrice(msgType, msgPrice, this.validFrom, {from: caller}), revertMsg)
            })
          })
        })
        context('when the TTL update is active', function() {
          beforeEach(async function() {
            await time.increase(InitialTTL)
          })
          context('when TTL is more than the new TTL in the future', function() {
            beforeEach(async function() {
              const validFrom = (await time.latest()).add(newTTL)
              this.validFrom = validFrom
              const { logs } = await this.msgOracle.setMsgPrice(msgType, msgPrice, validFrom, {from: caller})
              this.logs = logs
            })
            it('should emit a LogSetMsgPrice event', function() {
              expectEvent.inLogs(this.logs, 'LogSetMsgPrice', {
                swarmMsg: web3.utils.padRight(msgType, 64),
                price: msgPrice,
                validFrom: this.validFrom
              })
            })
          })
          context('when TTL is less than the new TTL in the future', function() {
            beforeEach(async function() {
              const validFrom = (await time.latest())
              this.validFrom = validFrom
            })
            const revertMsg = "MsgOracle: validFrom not oldTTL seconds in the future"
            it('reverts', async function() {
              await expectRevert(this.msgOracle.setMsgPrice(msgType, msgPrice, this.validFrom, {from: caller}), revertMsg)
            })
          })
        })
      })
    })
    context('when owner is not the caller', async function() {
      const caller = nonOwner
      const revertMsg = "Ownable: caller is not the owner"
      const validFrom = (await time.latest())
      it('reverts', async function() {
        await expectRevert(this.msgOracle.setMsgPrice(msgType, msgPrice, validFrom, {from: caller}), revertMsg)
      })
    })
  })

  describe('revertMsgPrice', function() {
    const msgType = web3.utils.fromAscii("mockMessage")
    const msgPrice = new BN(42)
    const validFrom = new BN(42)
    context('when owner is the caller', function() {
      const caller = owner
      beforeEach(async function() {
        const { logs } = await this.msgOracle.revertMsgPrice(msgType, msgPrice, validFrom, {from: caller})
        this.logs = logs
      })   
      it('should emit a LogRevertMsgPrice', function() {
        expectEvent.inLogs(this.logs, 'LogRevertMsgPrice', {
          swarmMsg: web3.utils.padRight(msgType, 64),
          price: msgPrice,
          validFrom: validFrom
        })
      })
    })
    context('when owner is not the caller', function() {
      const caller = nonOwner
      const revertMsg = "Ownable: caller is not the owner"
      it('reverts', async function() {
        await expectRevert(this.msgOracle.setMsgPrice(msgType, msgPrice, validFrom, {from: caller}), revertMsg)
      })
    })
  })
})