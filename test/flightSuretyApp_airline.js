
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests - Airline Registration', async (accounts) => {

    let newAirline2 = accounts[2];
    let newAirline3 = accounts[3];
    let newAirline4 = accounts[4];
    let newAirline5 = accounts[5];
    let newAirline6 = accounts[6];
    let newAirline7 = accounts[7];

    const payment = web3.utils.toWei("10","ether");

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

  /****************************************************************************************/
  /* Airline Registration                                                                 */
  /****************************************************************************************/

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline2, {from: config.owner});
        }
        catch(e) {

        }

        let result = await config.flightSuretyApp.IsAirlineRegistered.call(newAirline2); 

        // ASSERT
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    it('(airline) Able to submit funding', async () => {

        // ACT
        await config.flightSuretyApp.submitFunding({from: config.owner, value: payment});

        let result = await config.flightSuretyData.getFundingRecord.call(config.owner);

        // ASSERT
        assert.equal(result, payment, "Airline is able to submit funding");

    });

    it('(airline) Register First 4 Airlines', async () => {
        
        // ACT: register 3 airlines
        await config.flightSuretyApp.registerAirline(newAirline2, {from: config.owner});
        await config.flightSuretyApp.registerAirline(newAirline3, {from: config.owner});
        await config.flightSuretyApp.registerAirline(newAirline4, {from: config.owner});
            
        let result = await config.flightSuretyApp.numberRegisteredAirlines.call();

        // ASSERT
        assert.equal(result, 4, "First 4 airlines are registered");

    });

    it('(airline) Cannot vote twice and Register fifth & subsquent Airlines', async () => {
        let votedTwice = true;
        
        await config.flightSuretyApp.submitFunding({from: newAirline2, value: payment});

        // ACT: register 5th airlines
        await config.flightSuretyApp.registerAirline(newAirline5, {from: config.owner});

        // airline submitting votes for fifth airline
        await config.flightSuretyApp.voteAirlineRegistration(newAirline5, true, {from: config.owner});

        // Test on voting second time 
        try{
            await config.flightSuretyApp.voteAirlineRegistration(newAirline5, false, {from: config.owner});
        }
        catch(e){
            votedTwice = false;
        }

        // airline submitting votes for fifth airline
        await config.flightSuretyApp.voteAirlineRegistration(newAirline5, true, {from: newAirline2});

        let result5 = await config.flightSuretyApp.IsAirlineRegistered.call(newAirline5);

        // ASSERT
        assert.equal(votedTwice, false, "An airline cannot vote twice for new airline registration");
        assert.equal(result5, true, "The 5th airlines is registered after voting");
    });


    it('(airline) Cannot register 6th Airlines when multiparty consensus is NOT met', async () => {

        /* Scenario: There are five registered airlines and 3 are funded
                     Two voted "Yes" for registering 6th airline and One voted "No"*/
        
        await config.flightSuretyApp.submitFunding({from: newAirline3, value: payment});

        // ACT: register 6th airlines and 7th airline
        await config.flightSuretyApp.registerAirline(newAirline6, {from: newAirline2});

        // airline submitting two "Yes" votes for 6th airline
        await config.flightSuretyApp.voteAirlineRegistration(newAirline6, true, {from: config.owner});
        await config.flightSuretyApp.voteAirlineRegistration(newAirline6, true, {from: newAirline2});

        // one No vote for 6th airline
        await config.flightSuretyApp.voteAirlineRegistration(newAirline6, false, {from: newAirline3});

        result6 = await config.flightSuretyApp.IsAirlineRegistered.call(newAirline6);

        // ASSERT
        assert.equal(result6, false, "The 6th airlines is registered after voting");
    });

});
