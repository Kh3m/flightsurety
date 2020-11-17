pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    
    address private contractOwner;        
    uint8 threshold = 4;                    
    FlightSuretyData flightSuretyData; 

    uint256 public constant AirlineRegistrationFee = 10 ether;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }

    mapping(bytes32 => Flight) private flights;
    mapping(address => bool) private voted;                            // bool indicator on whether airline registration is being voted on



    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event RegisterAirline(address account);
    event voteAirlineRegistrationRequest(address account);
    event airlineVoted(address newAirline, address registered_airline, bool ballot);

    event FlightRegistration(address airline, string flightNumber, uint256 timestamp);
    event airlineSubmitFunding(address account, uint amount);
    event passengerPurchase(address airline, string flightNumber, uint256 timestamp, address passenger, uint256 amount);
    event insurancePayoutCredit(address airline, string flightNumber, uint256 timestamp);
    event withdrawalProcessed(address account, uint256 amount);

    
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

        // Define a modifier that checks if the paid amount is sufficient
      modifier paidEnough(uint _price)
      {
        require(msg.value >= _price, "Insufficient payment");
        _;
      }

    // Define a modifier that checks the price and refunds the remaining balance
    modifier checkValue(uint256 _price, address addressToFund)
    {
    
        _;
        uint256  amountToReturn = msg.value - _price;
        addressToFund.transfer(amountToReturn);
    
    }

    modifier maxInsuranceAmount()
    {
        require(msg.value <= 1 ether, "Insurance amount cannot exceed 1ETH");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address dataContract) 
        public 
    {
        contractOwner = msg.sender;
        
        flightSuretyData = FlightSuretyData(dataContract);

    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool) 
    {
        // return true;  // Modify to call data contract's status
        return flightSuretyData.isOperational();
    }

    function IsAirlineRegistered(address account) public view returns(bool) 
    {
        return flightSuretyData.getAirlineRegistrationStatus(account);
    }

    function ListRegistredAirline() public view returns(address[]) 
    {
        return flightSuretyData.ListRegistredAirline();
    }

    function IsAirlineOperational(address account) public view returns(bool) 
    {
        return flightSuretyData.getAirlineOperatingStatus(account);
    }

    function numberRegisteredAirlines() public view returns(uint) 
    {
        return flightSuretyData.multiCallsLength();
    }

    function getVoteCounterTally(address airline) public view returns(uint) 
    {
        return flightSuretyData.getVoteCounter(airline);
    }

    function getVotersTally(address airline) public view returns(uint) 
    {
        return flightSuretyData.getVoterLength(airline);
    }

    function getFlightStatus(address airline, string flightNumber, uint256 timestamp) public view returns(bool){
        bool status =  flightSuretyData.getFlightStatus(airline, flightNumber, timestamp);
        return status;
    }

    function getFlightStatusCode(address airline, string flightNumber, uint256 timestamp) public view returns(uint256){
        uint256 status =  flightSuretyData.getFlightStatusCode(airline, flightNumber, timestamp);
        return status;
    }

    function getFlightPremium(address airline, string flightNumber, uint256 timestamp) public view returns(uint256){
        return flightSuretyData.getFlightPremium(airline, flightNumber, timestamp);
    }

    function getInsureeList(address airline, string flightNumber, uint256 timestamp) public view returns(address []){
        return flightSuretyData.getInsureeList(airline, flightNumber, timestamp);
    }

    function getInsureeAmount(address airline, string flightNumber, uint256 timestamp, address insuree) public view returns(uint256){
        return flightSuretyData.getInsureeAmount(airline, flightNumber, timestamp, insuree);
    }

    function getAccountCredit(address account) public view returns(uint256){
        return flightSuretyData.getAccountCredit(account);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address airline) external
        requireIsOperational
    {
        require(airline != address(0), "'account' must be a valid address.");
        require(flightSuretyData.getAirlineOperatingStatus(msg.sender), "Caller airline is not operational - Need to submit 10ETH");
        require(!flightSuretyData.getAirlineRegistrationStatus(airline), "Airline is already registered");

        uint MultiCallAccounts = numberRegisteredAirlines();

        if (MultiCallAccounts < threshold){
            // Register airline directly in this case
            flightSuretyData.registerAirline(airline, false);
            emit RegisterAirline(airline);
        } else {
            emit voteAirlineRegistrationRequest(airline);
        }
    }

    /**
    * @dev Approve registration of fifth and subsequent airlines
    *
    */

    function voteAirlineRegistration(address airline, bool airline_vote) public 
        requireIsOperational
    {
        require(numberRegisteredAirlines() >= threshold, "Few than 4 airlines are registered");
        require(!flightSuretyData.getAirlineRegistrationStatus(airline),"Airline is already registered");
        require(flightSuretyData.getAirlineOperatingStatus(msg.sender),"Airline voter is not operational - Need to submit 10ETH");
        
        // Check and avoid duplicate vote for the same airline
        bool isDuplicate = false;
        uint256 numberOfExistingVoters = flightSuretyData.getVoterLength(airline);
        uint256 MultiCallAccounts = numberRegisteredAirlines();

        if (numberOfExistingVoters == 0){
            isDuplicate = false;
        } else {
            address[] memory ExistingVoters = flightSuretyData.getVoter(airline);

            for(uint c =0; c < numberOfExistingVoters; c++){
                if(ExistingVoters[c] == msg.sender){
                    isDuplicate = true;
                    break;
                }
            }
        }

        // Check to avoid same registered airline voting multiple times
        require(!isDuplicate, "Caller has already voted.");
        flightSuretyData.addVoters(airline, msg.sender, airline_vote);
        emit airlineVoted(airline, msg.sender, airline_vote);

        if(airline_vote == true){
            flightSuretyData.addVoterCounter(airline, 1);
        }
        
        uint256 voteCount = flightSuretyData.getVoteCounter(airline);
        uint256 multipartyThreshold; 

        //Calculate 50% of the numbers of registered airline
        if((MultiCallAccounts%2)==1){
            multipartyThreshold = MultiCallAccounts.div(2).add(1);
        } else {
            multipartyThreshold = MultiCallAccounts.div(2);
        }

        if(voteCount >= multipartyThreshold){
            // Airline has been voted in
            flightSuretyData.registerAirline(airline, false);
            
            flightSuretyData.resetVoteCounter(airline);

            emit RegisterAirline(airline);
        }

        if(numberOfExistingVoters == MultiCallAccounts){
            // Everyone is votes, thus close voting
            flightSuretyData.resetVoteCounter(airline);
        }
    }


    function submitFunding() payable public
        requireIsOperational
        paidEnough(AirlineRegistrationFee)
        checkValue(AirlineRegistrationFee,msg.sender)
    {

        // Make sure airline has not yet been funded
        require(!flightSuretyData.getAirlineOperatingStatus(msg.sender), "Airline is already funded");

        // Make sure airline is registered
        require(flightSuretyData.getAirlineRegistrationStatus(msg.sender),"Airline is not yet registered");

        // pass ETH to data contract
        flightSuretyData.fund.value(AirlineRegistrationFee)(msg.sender);

        emit airlineSubmitFunding(msg.sender, AirlineRegistrationFee);

    }

   /**
    * @dev Register a future flight for insuring.
    * only airline can register flights
    */  
    function registerFlight(string flightNumber, uint256 timestamp) external
        requireIsOperational
    {
        // Make sure airline has is funded
        require(flightSuretyData.getAirlineOperatingStatus(msg.sender), "Airline is yet funded");

        // Make sure flight is not registered
        require(!getFlightStatus(msg.sender, flightNumber, timestamp),"Flight is already registered");

        flightSuretyData.addFlight(msg.sender, flightNumber, timestamp);
        emit FlightRegistration(msg.sender, flightNumber, timestamp);

    }

    function submitPurchase(address airline, string flightNumber, uint256 timestamp) payable public
        requireIsOperational
        maxInsuranceAmount
    {
        // Make sure flight is registered
        require(getFlightStatus(airline, flightNumber, timestamp), "Flight is not yet registered");

        // pass ETH to data contract
        flightSuretyData.buy.value(msg.value)(airline, flightNumber, timestamp, msg.sender, msg.value);

        emit passengerPurchase(airline, flightNumber, timestamp, msg.sender, msg.value);

    }

    function submitWithdrawal(uint256 amount) payable public{
        // checks
        require(msg.sender == tx.origin, "Passenger account is needed to make withdrawal");  // check whether caller is EOA
        require(getAccountCredit(msg.sender) >= amount,"Insufficient credit in your account");

        //  Effects
        flightSuretyData.pay(msg.sender, amount);
        emit withdrawalProcessed(msg.sender, amount);
    }


    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus(
        uint8 index,
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    )
        internal
    {
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        oracleResponses[key].isOpen = false;
        flightSuretyData.addFlightStatusCode(airline, flight, timestamp, statusCode);

        if(statusCode == 20){
            flightSuretyData.creditInsurees(airline, flight, timestamp);
            emit insurancePayoutCredit(airline, flight, timestamp);
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp                            
    )
        public
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 5;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() external payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    )
        public
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), 
                "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);

        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(index, airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    )
        pure
        internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3]){
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8){
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

contract FlightSuretyData {
    function isOperational() public view returns(bool);

    // Airlines
    function registerAirline(address account, bool funded) external;
    function getAirlineOperatingStatus(address account) external returns(bool);
    function getAirlineRegistrationStatus(address account) external returns(bool);

    // fund
    function fund(address account) payable public;

    // MultiCall
    function ListRegistredAirline() external returns(address[]);
    function multiCallsLength() external returns(uint);
    function addVoterCounter(address airline, uint count) external;
    function getVoteCounter(address account) external  returns(uint);
    function setVoteCounter(address account, uint vote) external;
    function resetVoteCounter(address account) external;
    function addVoters(address newAirline, address account, bool vote) external;
    function getVoter(address account) external returns(address[]);
    function getVoterLength(address account) external returns(uint);

    // flight info
    function addFlight(address airline, string newflight, uint256 timestamp) external;
    function getFlightStatus(address airline, string flightNumber, uint256 timestamp) external returns(bool);
    function getFlightPremium(address airline, string flightNumber, uint256 timestamp) external returns(uint256);
    function addFlightStatusCode(address airline,string newFlight, uint256 timestamp, uint256 statusCode) external;
    function getFlightStatusCode(address airline, string flightNumber, uint256 timestamp) external returns (uint256);

    // Passenger
    function buy(address airline, string flightNumber, uint256 timestamp, address insuree, uint256 amount) external payable;
    function getInsureeList(address airline, string flightNumber, uint256 timestamp) external returns(address []);
    function getInsureeAmount(address airline, string flightNumber, uint256 timestamp, address insuree) external returns(uint256);

    //Payout
    function creditInsurees(address airline, string flightNumber, uint256 timestamp) external;
    function getAccountCredit(address account) external returns(uint256);

    //Withdrwal
    function pay(address account, uint256 amount) external payable;

}
