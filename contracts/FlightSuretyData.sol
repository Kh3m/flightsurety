pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false


    // mine
    struct Airlines{
        bool isRegistered;
        bool isOperational;
    }

    address[] multiCalls = new address[](0);

    struct Voters {
        address[] airlineVoter;
        mapping(address => bool) results;
    }

    struct insureeDetail {
        uint256 insuranceAmount;
        uint256 payout;
    }

    struct flightDetail {
        bool isRegistered; 
        uint256 totalPremium;
        uint256 statusCode;
    }

    mapping(address => uint256) private voteCount;
    mapping(address => Airlines) airlines;
    mapping(address => uint256) private funding;
    mapping(address => Voters) voters;
 

    mapping(address => uint256) private authorizedCaller;
    
    mapping(address => uint256) accountCredit;   //keep track of each passenger's account balance

    // Per flight info
    mapping(address => bytes32 []) flightList; 
    mapping(address => mapping(bytes32 => flightDetail)) flights;     
    mapping(address => mapping(bytes32 => address [])) insureeList;  
    mapping(address => mapping(bytes32 => mapping(address => insureeDetail))) insurees;    

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AuthorizedContract(address contractAddress);
    event DeAuthorizedContract(address contractAddress);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;

        // Initialize the first airline
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

    // is caller auth
    modifier onlyAuthorizedCaller()
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
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
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
        // deauthorize contract address
        delete authorizedCaller[contractAddress];
        emit DeAuthorizedContract(contractAddress);
    } 

    function setAirlineOperateStatus(address account, bool status) private
        requireIsOperational
    {
        airlines[account].isOperational = status;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address account, bool paid
                            )
                            external

        requireIsOperational
        onlyAuthorizedCaller
    {
        airlines[account] = Airlines({
            isRegistered: true,           // isRegistered is always true for a registered airline
            isOperational: paid  // isOperational is only true when airline has submited 10 Ether 
        });

        multiCalls.push(account);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (   
                                address airline,
                                string flightNumber,
                                uint256 time,
                                address insuranceReceiver,
                                uint256 amount             
                            )
                            external
                            payable
        requireIsOperational
        onlyAuthorizedCaller
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, time));

        flights[airline][key].totalPremium = flights[airline][key].totalPremium.add(amount);     

        insureeList[airline][key].push(insuranceReceiver);

        insurees[airline][key][insuranceReceiver] = insureeDetail({
                                        insuranceAmount: amount,
                                        payout: 0
                                });
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline, string flightNumber, uint256 time
                                )
                                external
        requireIsOperational
        onlyAuthorizedCaller
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, time));
        address [] creditAccounts = insureeList[airline][key];
        uint256 accountsLength = creditAccounts.length;

        require(accountsLength > 0, "insurees for the delayed flight not found");

        for(uint256 i =0; i < accountsLength; i++){
            uint256 creditAmount = 0;
            address account = creditAccounts[i];
            creditAmount = insurees[airline][key][account].insuranceAmount.mul(3).div(2);
            insurees[airline][key][account].payout = creditAmount;
            accountCredit[account] = accountCredit[account].add(creditAmount);
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address account, uint256 amount
                            )
                            external
                            payable
        requireIsOperational
        onlyAuthorizedCaller
    {
        accountCredit[account] = accountCredit[account].sub(amount);
        account.transfer(amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                                address account
                            )
                            public
                            payable
        requireIsOperational
        onlyAuthorizedCaller
    {
        funding[account] = msg.value;
        setAirlineOperateStatus(account, true);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund(msg.sender);
    }

    function getRegistrationStatus(address account) external 
        requireIsOperational
        onlyAuthorizedCaller
        returns(bool)
    {
        return airlines[account].isRegistered;
    }


    function multiCallsLength() external 
        requireIsOperational
        onlyAuthorizedCaller 
        returns(uint)
    {
        return multiCalls.length;
    }

    // mine

    function setFlightStatusCode(address airline,string newFlight, uint256 timestamp, uint256 statusCode) external
        requireIsOperational
        onlyAuthorizedCaller
    {
        bytes32 key = keccak256(abi.encodePacked(newFlight, timestamp));
        flights[airline][key].statusCode = statusCode;

    }

    function getFlightStatusCode(address airline, string flightNumber, uint256 timestamp) external
        requireIsOperational
        onlyAuthorizedCaller
        returns(uint256)
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));
        uint256 status = flights[airline][key].statusCode;
        return status;
    }

    function getFlightStatus(address airline, string flightNumber, uint256 timestamp) external
        requireIsOperational
        onlyAuthorizedCaller
        returns(bool)
    {
        bytes32 key = keccak256(abi.encodePacked(flightNumber, timestamp));
        bool status = flights[airline][key].isRegistered;
        return status;
    }

    function getOperatingStatus(address account) external
        requireIsOperational
        onlyAuthorizedCaller
        returns(bool)
    {
        return airlines[account].isOperational;
    }

    function addFlight(address airline,string newFlight, uint256 timestamp) external
        requireIsOperational
        onlyAuthorizedCaller
    {
        bytes32 key = keccak256(abi.encodePacked(newFlight, timestamp));
        flightList[airline].push(key);
        flights[airline][key].isRegistered = true;
        flights[airline][key].totalPremium = 0;
        flights[airline][key].statusCode = 0;

    }

}

