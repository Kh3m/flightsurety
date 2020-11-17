pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    
    //data variables for airlines and MultiCalls
    address[] multiCalls = new address[](0);
    
    struct Airlines{
        bool isRegistered;
        bool isOperational;
    }

    struct Voters{
        address[] airlineVoter;
        mapping(address => bool) voteResults;
    }

    // for passenger
    struct insureeInfo{
        uint256 insuranceAmount;
        uint256 payout;
    }

    // for flight
    struct flightInfo{
        bool isRegistered; 
        uint256 totalPremium;
        uint256 statusCode;
    }

    mapping(address => Airlines) airlines;
    mapping(address => Voters) voters;
    mapping(address => uint256) private voteCount;
    mapping(address => uint256) private funding;

    // operational control
    mapping(address => uint256) private authorizedCaller;

    // passenger
    mapping(address => uint256) accountCredit;   //keep track of each passenger's account balance

    // Per flight info
    mapping(address => bytes32 []) flightList; 
    mapping(address => mapping(bytes32 => flightInfo)) flights;     // flight info for each airline
    mapping(address => mapping(bytes32 => address [])) insureeList;   //store the passenger addresses for each flight
    mapping(address => mapping(bytes32 => mapping(address => insureeInfo))) insurees;    //For each flight, it keeps track of premium and payout for each insuree

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AuthorizedContract(address authContract);
    event DeAuthorizedContract(address authContract);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public 
    {
        contractOwner = msg.sender;
        
        airlines[msg.sender] = Airlines({
            isRegistered: true,
            isOperational: false
        }); 

        multiCalls.push(msg.sender);

    }

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
        require(operational, "Contract is currently not operational");
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

    modifier isCallerAuthorized()
    {
        require(authorizedCaller[msg.sender] == 1, "Caller is not authorized");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode) external
        requireContractOwner 
    {
        operational = mode;
    }

    function authorizeCaller(address contractAddress) external
        requireContractOwner
    {
        authorizedCaller[contractAddress] = 1;
        emit AuthorizedContract(contractAddress);
    }

    function deauthorizeContract(address contractAddress) external
        requireContractOwner
    {
        delete authorizedCaller[contractAddress];
        emit DeAuthorizedContract(contractAddress);
    } 

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function multiCallsLength() external 
        requireIsOperational
        isCallerAuthorized 
        returns(uint)
    {
        return multiCalls.length;
    }

    function ListRegistredAirline() external 
        requireIsOperational
        isCallerAuthorized 
        returns(address[])
    {
        return multiCalls;
    }

    function addVoterCounter(address newAirline, uint count) external
        requireIsOperational
        isCallerAuthorized
    {
        voteCount[newAirline] = voteCount[newAirline].add(count); 
    }

    function getVoteCounter(address account) external 
        requireIsOperational 
        isCallerAuthorized
        returns(uint)
    {
        return voteCount[account];
    }

    function resetVoteCounter(address account) external 
        requireIsOperational
        isCallerAuthorized
    {
        delete voteCount[account];
    }

    function addVoters(address newAirline, address account, bool vote) external
        requireIsOperational
        isCallerAuthorized
    {
        voters[newAirline].airlineVoter.push(account);
        voters[newAirline].voteResults[account] = vote;
    }

    function getVoter(address account) external 
        requireIsOperational
        isCallerAuthorized
        returns(address[])
    {
        address[] memory v = voters[account].airlineVoter;
        return v;
    }

    function getVoterLength(address account) external 
        requireIsOperational
        isCallerAuthorized
        returns(uint)
    {
        return voters[account].airlineVoter.length;
    }

    function getAirlineRegistrationStatus(address account) external 
        requireIsOperational
        isCallerAuthorized
        returns(bool)
    {
        return airlines[account].isRegistered;
    }

    function setAirlineOperatingStatus(address account, bool status) private
        requireIsOperational
    {
        airlines[account].isOperational = status;
    }

    function getAirlineOperatingStatus(address account) external
        requireIsOperational
        isCallerAuthorized
        returns(bool)
    {
        return airlines[account].isOperational;
    }


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(address account, bool funded) external
        requireIsOperational
        isCallerAuthorized
    {
        airlines[account] = Airlines({
            isRegistered: true,           // isRegistered is always true for a registered airline
            isOperational: funded  // isOperational is only true when airline has submited 10 Ether 
        });

        multiCalls.push(account);

    }

    function addFlight(address airline,string newFlight, uint256 timestamp) external
        requireIsOperational
        isCallerAuthorized
    {
        bytes32 key = keccak256(abi.encodePacked(newFlight, timestamp));
        flightList[airline].push(key);
        flights[airline][key].isRegistered = true;
        flights[airline][key].totalPremium = 0;
        flights[airline][key].statusCode = 0;

    }

    function getFlightStatus(address airline, string flightNumber, uint256 timestamp) external
        requireIsOperational
        isCallerAuthorized
        returns(bool)
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));
        bool status = flights[airline][key].isRegistered;
        return status;
    }

    function addFlightStatusCode(address airline,string newFlight, uint256 timestamp, uint256 statusCode) external
        requireIsOperational
        isCallerAuthorized
    {
        bytes32 key = keccak256(abi.encodePacked(newFlight, timestamp));
        flights[airline][key].statusCode = statusCode;

    }

    function getFlightStatusCode(address airline, string flightNumber, uint256 timestamp) external
        requireIsOperational
        isCallerAuthorized
        returns(uint256)
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));
        uint256 status = flights[airline][key].statusCode;
        return status;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(address airline, string flightNumber, uint256 timestamp, address insuree, uint256 amount) external payable
        requireIsOperational
        isCallerAuthorized
    {
        //increment total premiums collected for the flight
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));

        flights[airline][key].totalPremium = flights[airline][key].totalPremium.add(amount);     

        insureeList[airline][key].push(insuree);             // add insuree to the flight's insuree list

        insurees[airline][key][insuree]= insureeInfo({
                                        insuranceAmount: amount,
                                        payout: 0
                                        });

    }

    function getFlightPremium(address airline, string flightNumber, uint256 timestamp) external
        requireIsOperational
        isCallerAuthorized
        returns(uint256)
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));
        return flights[airline][key].totalPremium;
    }

    function getInsureeList(address airline, string flightNumber, uint256 timestamp) external
        requireIsOperational
        isCallerAuthorized
        returns(address [])
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));
        return insureeList[airline][key];
    }

    function getInsureeAmount(address airline, string flightNumber, uint256 timestamp, address insuree) external
        requireIsOperational
        isCallerAuthorized
        returns(uint256)
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));
        return insurees[airline][key][insuree].insuranceAmount;
    }


    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address airline, string flightNumber, uint256 timestamp) external
        requireIsOperational
        isCallerAuthorized 
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));
        address [] creditAccounts = insureeList[airline][key];
        uint256 accountsLength = creditAccounts.length;

        require(accountsLength > 0, "No insurees for the delayed flight");

        for(uint256 i =0; i < accountsLength; i++){
            uint256 creditAmount = 0;
            address account = creditAccounts[i];
            creditAmount = insurees[airline][key][account].insuranceAmount.mul(3).div(2);
            
            // update insureeInfo of flight 
            insurees[airline][key][account].payout = creditAmount;

            // update individal passenger account credit
            accountCredit[account] = accountCredit[account].add(creditAmount);
        }
    }

    function getAccountCredit(address account) external
        requireIsOperational
        isCallerAuthorized
        returns(uint256)
    {
        return accountCredit[account];
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address account, uint256 amount) external payable  
        requireIsOperational
        isCallerAuthorized
    {
        accountCredit[account] = accountCredit[account].sub(amount);
        account.transfer(amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address account) payable public
        requireIsOperational
        isCallerAuthorized
    {
        funding[account] = msg.value;
        setAirlineOperatingStatus(account, true);
    }

    function getFundingRecord(address account) public
        requireIsOperational
        returns(uint256)
    {
        uint256 record = funding[account];
        return record;
    }


    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    )
        pure
        internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable 
    {
        fund(msg.sender);
    }


}

