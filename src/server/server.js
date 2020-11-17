import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import { Random } from "random-js";
import { resolve } from 'path';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];

let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
let firstAirline;
let airlines;
var orcales = [];
let allFlight = [];
const random = new Random();
let flights = ["NY9200","CA8300","SF7100","BA0900","SA1200","TN2300"];

class flight {
  constructor(flightNumber,airline){
    this.flightNumber = flightNumber;
    this.airline = airline;
    this.timestamp = (new Date).getTime() + random.integer(10000,800000);
    // this.price = web3.utils.toWei((Math.floor(Math.random()*10+1)/10).toString(),"ether");
  }
}

(async() => {
  let accounts = await web3.eth.getAccounts();
  // first airline is also owner of the contract
  firstAirline = accounts[0];

  try{
    await flightSuretyData.methods.authorizeCaller(flightSuretyApp._address).send({from: firstAirline});
  } catch(e){
    console.log("Cannot authorize App contract");
  }

  // fee for registering oracle
  let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  
  // fee for registering airline
  let airlineFee = await flightSuretyApp.methods.AirlineRegistrationFee().call();
  // console.log(airlineFee);
  // console.log(fee);

  let OracleAccounts = accounts.splice(10,39);
  airlines = accounts.splice(1,3);
  // console.log(airlines);
  // console.log(OracleAccounts);

    // first airline submit funding
    try{
      await flightSuretyApp.methods.submitFunding().send({from:firstAirline, value:airlineFee});
    }catch(e){
      console.log("First airline funding did not go through");
      console.log(e);
    }
  
  // without specifying gas and gasPrice, it would show VM revert error
  for(let a = 0; a < airlines.length; a++){
    try{
        await flightSuretyApp.methods.registerAirline(airlines[a]).send(
          {
            from:firstAirline,
            gas: 4712388,
            gasPrice: 100000000000
          }
        );
        await flightSuretyApp.methods.submitFunding().send({from:airlines[a], value:airlineFee});
        // let isReg = await flightSuretyApp.methods.IsAirlineRegistered(airlines[a]).call();
        // console.log(isReg);
    }catch(error){
      console.log("Cannot register 3 more airlines");
      console.log(error);
    }
  }

  // register orcales

  for(let c =0; c < OracleAccounts.length; c++){
    try{
      // const estimateGas = await flightSuretyApp.methods.registerOracle().estimateGas({from: OracleAccounts[c], value: fee});
      await flightSuretyApp.methods.registerOracle().send({
          from: OracleAccounts[c], 
          value:fee,
          gas: 4712388,
          gasPrice: 100000000000
      });
      let index = await flightSuretyApp.methods.getMyIndexes().call({from: OracleAccounts[c]});
      orcales.push({
        address : OracleAccounts[c],
        indexes : index
      })
    }catch(error){
      console.log("Cannot register Oracles");
      console.log(error);
    }
  }
})();

console.log("Registering Orcales && Airlines...");

(function() {
  var P = ["\\", "|", "/", "-"];
  var x = 0;
  return setInterval(function() {
    process.stdout.write("\r" + P[x++]);
    x &= 3;
  }, 250);
})();

setTimeout(() => {
  orcales.forEach(orcale => {
    console.log(`Oracle Address: ${orcale.address}, has indexes: ${orcale.indexes}`);
  })
  console.log("\nAwaiting event OracleRequest to submit responses")
}, 25000)


function randomStatus(){
  const random = new Random(); 
    return (Math.ceil((random.integer(1, 50)) / 10) * 10);
}

// watch for OracelRequest event
// If an request is made, Oracles would report back status codes that are ramdonly generated
// event OracleRequest(index, airline, flight, timestamp)
// function submitOracleResponse(uint8 index, address airline, string flight, uint256 timestamp, uint8 statusCode)

flightSuretyApp.events.OracleRequest({
  fromBlock: 0
}, function (error, event) {
    if (error) {
      console.log(error);
    }else {
      console.log(event)
      
      let randomStatusCode = randomStatus();
      console.log(randomStatusCode);
      let eventValue = event.returnValues;
      console.log(eventValue);
      console.log(`Catch a new event with randome index: ${eventValue.index} for flight: ${eventValue.flight} and timestamp ${eventValue.timestamp}`);

      orcales.forEach((oracle) => {
          flightSuretyApp.methods.submitOracleResponse(eventValue.index, eventValue.airline, eventValue.flight, eventValue.timestamp, randomStatusCode)
            .send(
              {from: oracle.address,
               gas: 4712388,
               gasPrice: 100000000000
            }).then(res => {
              console.log(`--> Oracles(${oracle.address}) accepted with status code ${randomStatusCode}`)
            }).catch(err => {
              console.log(`--> Oracles(${oracle.address}) rejected with status code ${randomStatusCode}`)
            }
          );
      });
    }
  }
);

// Six flights are registered
// when flight depart time is true, user can look up flight status

const app = express();

app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  next();
});

app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

app.get('/api/fetchFlights', (req, res) => {
  while(allFlight.length > 0) {
    allFlight.pop();
  }
  
  for(let a = 0; a < flights.length; a ++){ 
    const random = new Random();
    let newAirline = airlines[random.integer(0, airlines.length -1 )];
    let newFlight = new flight(flights[a],newAirline);
    let timestamp = Math.floor(newFlight.timestamp / 1000);
    allFlight.push(newFlight);
    (async() => {
      try{
        // const estimateGas = await flightSuretyApp.methods.registerFlight(newFlight.flightNumber, newFlight.timestamp).estimateGas({from: newFlight.airline});
        console.log(newFlight.flightNumber,newFlight.timestamp,newFlight.airline)
        await flightSuretyApp.methods.registerFlight(newFlight.flightNumber, newFlight.timestamp).send(
          {
            from: newFlight.airline, 
            gas: 4712388,
            gasPrice: 100000000000
          }
        );
        let result = await flightSuretyApp.methods.getFlightStatus(newFlight.airline,newFlight.flightNumber,newFlight.timestamp).call();
        console.log(result);
      }catch(error){
        console.log(error);
      }
    })();
  }
  res.status(200).send(allFlight);
})

export default app;


