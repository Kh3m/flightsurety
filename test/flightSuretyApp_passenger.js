
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests - Passengers', async (accounts) => {

    // flights from first airline
    const flightNumber1 = "DL1270";
    const flightNumber2 = "DL1280";
    const timestamp = Math.floor(Date.now()/ 1000);

    // flights from second airline

    let airline2 = accounts[2];
    // let newAirline3 = accounts[3];
    // let newAirline4 = accounts[4];
    // let newAirline5 = accounts[5];
    // let newAirline6 = accounts[6];
    // let newAirline7 = accounts[7];
    let passenger1 = accounts[10];
    let passenger2 = accounts[11];
    const payment = web3.utils.toWei("10","ether");
    const payment_half = web3.utils.toWei("0.5","ether");
    const payment_1 = web3.utils.toWei("1","ether");

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);

        // Airline 1 is funded
        await config.flightSuretyApp.submitFunding({from: config.owner, value: payment});

        // Airline 2 is registered and funded
        await config.flightSuretyApp.registerAirline(airline2, {from: config.owner});
        await config.flightSuretyApp.submitFunding({from: airline2, value: payment});

    });

  /****************************************************************************************/
  /* Passenger TX                                                                         */
  /****************************************************************************************/

    it('(airline) Able to register flight and flight number is correct', async () => {
        let result = true;

        try{
            await config.flightSuretyApp.registerFlight(flightNumber1, timestamp, {from: config.owner})
        }
        catch(e){
            result = false;
        }

        await config.flightSuretyApp.registerFlight(flightNumber2, timestamp, {from: config.owner})

        result2 = await config.flightSuretyApp.getFlightStatus(config.owner, flightNumber2, timestamp);

        // ASSERT
        assert.equal(result, true, "Airline is able to register flight");
        assert.equal(result2, true, "Flight numbers is correct");

    });  
  
  
    it('(Passenger) can purchase insurance and records are kept correctly', async () => {
        let totalPremium = web3.utils.toWei("1.5","ether");

        // ACT
        await config.flightSuretyApp.submitPurchase(config.owner, flightNumber1, timestamp, {from: passenger1, value: payment_half});
        await config.flightSuretyApp.submitPurchase(config.owner, flightNumber1, timestamp, {from: passenger2, value: payment_1});

        let result = await config.flightSuretyApp.getFlightPremium.call(config.owner, flightNumber1, timestamp);

        let insureeList = await config.flightSuretyApp.getInsureeList.call(config.owner, flightNumber1, timestamp);
        // console.log(insureeList);
        let insuree1 = insureeList[0];
        let insuree2 = insureeList[1];

        let insureeAmount1 = await config.flightSuretyApp.getInsureeAmount.call(config.owner, flightNumber1, timestamp, insuree1);
        let insureeAmount2 = await config.flightSuretyApp.getInsureeAmount.call(config.owner, flightNumber1, timestamp, insuree2);

        // ASSERT
        assert.equal(result, totalPremium, "Total Premium record for a flight is correct");  //Check total premium record
        assert.equal(insureeAmount1, payment_half, "Individual insuree premium record for a flight is correct");
        assert.equal(insureeAmount2, payment_1, "Individual insuree premium record for a flight is correct");

    });

    /*Scenario: Passenger1 pays 0.5ETH premium and Passenger2 pays 1ETH on insurance on flight1 operated by config.owner(first airline) 
                Flight1 is delayed due to airline's fault
    */
    it('(Passenger) can receive insurance payout credit', async () => {

        /* simulate Oracles runtime*/

        // Register Oracles
        const TEST_ORACLES_COUNT = 40;
        const STATUS_CODE_LATE_AIRLINE = 20;
        let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

        for(let a=10; a<TEST_ORACLES_COUNT; a++) {      
          await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
          let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
          console.log(`Oracle ${accounts[a]} Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
        }

        // Generate Oracle response
        // let timestamp = Math.floor(Date.now() / 1000);

        // Submit a request for oracles to get status information for a flight
        try{
          let result = await config.flightSuretyApp.fetchFlightStatus(config.owner, flightNumber1, timestamp);
          // console.log(result);
        }catch(e){
          console.log(e);
        }
        

        for(let a=10; a<TEST_ORACLES_COUNT; a++) {

            // Get oracle information
            let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
            for(let idx=0;idx<3;idx++) {
      
              try {
                // Submit a response...it will only be accepted if there is an Index match
                await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.owner, flightNumber1, timestamp, STATUS_CODE_LATE_AIRLINE, { from: accounts[a] });
                console.log('\nSuccess', idx, oracleIndexes[idx].toNumber(), flightNumber1, timestamp);
              }
              catch(e) {
                // Enable this when debugging
                // console.log(e);
                //  console.log('\nError', idx, oracleIndexes[idx].toNumber(), flightNumber1, timestamp);
              }
    
            }
        }

        let insureeList = await config.flightSuretyApp.getInsureeList.call(config.owner, flightNumber1, timestamp);
        var insuree1 = insureeList[0];
        var insuree2 = insureeList[1];

        // Passenger1 insurance payout = 0.5ETH x 1.5 = 0.75ETH
        // Passenger2 insurance payout = 1ETH x 1.5 = 1.5ETH
        var insurancePayout1 = web3.utils.toWei("0.75","ether");
        var insurancePayout2 = web3.utils.toWei("1.5","ether");
        
        let accountCredit1 = await config.flightSuretyApp.getAccountCredit(insuree1);
        let accountCredit2 = await config.flightSuretyApp.getAccountCredit(insuree2);


        // ASSERT
        assert.equal(accountCredit1, insurancePayout1, "Crediting insuree account for a flight payout is correct");
        assert.equal(accountCredit2, insurancePayout2, "Crediting insuree account for a flight payout is correct");

    });

    /*Scenario: Passenger1 has 0.75ETH and Passenger2 has 1.5ETH credit on their account*/
    it('(Passenger) can withdraw from their credit accounts', async () => {

        var withdrawalAmount1 = web3.utils.toWei("0.5","ether");
        var withdrawalAmount2 = web3.utils.toWei("1","ether");
        let priorBalance1  = await web3.eth.getBalance(passenger1);
        let priorBalance2 = await web3.eth.getBalance(passenger2);
        let expectedBalance1  = BigNumber.sum(priorBalance1,withdrawalAmount1);
        let expectedBalance2 = BigNumber.sum(priorBalance2, withdrawalAmount2);
        // console.log(expectedBalance1);
        
        // Passenger1
        const receipt1 = await config.flightSuretyApp.submitWithdrawal(withdrawalAmount1,{from: passenger1});
        const gasUsed1 = receipt1.receipt.gasUsed;
            
            // Obtain gasPrice from the transaction and calcualtion transaction cost 
        const tx1 = await web3.eth.getTransaction(receipt1.tx);
        const gasPrice1 = tx1.gasPrice;
        var gasCost1 = BigNumber(gasUsed1).multipliedBy(BigNumber(gasPrice1));
        // console.log(gasUsed1, gasPrice1, gasCost1)

        // Passenger2
        const receipt2 = await config.flightSuretyApp.submitWithdrawal(withdrawalAmount2,{from: passenger2});
        const gasUsed2 = receipt2.receipt.gasUsed;
        const tx2 = await web3.eth.getTransaction(receipt2.tx);
        const gasPrice2 = tx2.gasPrice;
        var gasCost2 = BigNumber(gasUsed2).multipliedBy(BigNumber(gasPrice2));

        let currentBalance1 =  await web3.eth.getBalance(passenger1);
        let currentBalance2 = await web3.eth.getBalance(passenger2);
        // console.log(BigNumber(currentBalance1));


        let result1 = expectedBalance1.isEqualTo(BigNumber.sum(currentBalance1,gasCost1));
        let result2 = expectedBalance2.isEqualTo(BigNumber.sum(currentBalance2,gasCost2));

        // ASSERT
        assert.equal(result1, true, "Passenger withdrawal is correct");
        assert.equal(result2, true, "Passenger withdrawal is correct");

    });


});
