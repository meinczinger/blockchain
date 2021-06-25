pragma solidity ^0.5.10;

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

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    // Number of airlines, above which voting is required
    uint8 private constant AIRLINE_VOTING_LIMIT = 4;
    // Number of votes required
    uint8 private constant AIRLINE_REGISTRATION_VOTES_REQUIRED = 2;
    // Maximum insurance amount a passenger can buy
    uint256 private constant MAX_INSURANCE_LIMIT = 1 ether;
    // Stake an airline has to provide to be able to get registered
    uint256 private constant AIRLINE_MINIMUM_STAKE = 10 ether;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;


    // During the voting, store the airlines, which have already provided their voting
    mapping(address => address[]) votingAirlines;

    FlightSuretyData flightSuretyData;
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
        require(true, "Contract is currently not operational");
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

    /**
    * @dev Modifier that requires that an airline is not registered yet
    */
    modifier requireAirlineIsNotYetRegistered(address airline) {
        require(!flightSuretyData.isAirlineRegistered(airline), "Airline is already registered.");
        _;
    }

    /**
    * @dev Modifier that requires that an airline is already registered
    */
    modifier requireAirlineIsRegistered(address airline) {
        require(flightSuretyData.isAirlineRegistered(airline), "Airline is not yet registered.");
        _;
    }

    /**
    * @dev Modifier that requires that an airline is funded
    */
    modifier requireIsAirlineFunded(address airline) {
        require(flightSuretyData.isAirlineFunded(airline), "Airline is not funded.");
        _;
    }

    /**
    * @dev Modifier that requires that an airline is not yet funded
    */
    modifier requireAirlineNotYetFunded(address airline) {
        require(!flightSuretyData.isAirlineFunded(airline), "Airline is not funded.");
        _;
    }

    /**
    * @dev Modifier that requires sufficient funding to fund an airline
    */
    modifier requireEnoughFundingProvided() {
        require(msg.value >= AIRLINE_MINIMUM_STAKE, "Insufficient Funds.");
        _;
    }

    /**
    * @dev Modifier that requires a flight to be registered
    */
    modifier requireFlightIsRegistered(bytes32 flightKey) {
        require(flightSuretyData.isFlightRegistered(flightKey), "Flight is not yet registered.");
        _;
    }

    /**
    * @dev Modifier that requires a flight is not yet landed
    */
    modifier requireFlightNotYetLanded(bytes32 flightKey) {
        require(!flightSuretyData.isFlightLanded(flightKey), "Flight has already landed");
        _;
    }

    /**
    * @dev Modifier that requires a passanger not yet been insured (to avoid double-insurance)
    */
    modifier requirePassengerNotYetInsuredForFlight(bytes32 flightKey, address passenger) {
        require(!flightSuretyData.isPassengerInsured(flightKey, passenger), "Passenger is already insured for flight");
        _;
    }

    /**
    * @dev Modifier that requires a passanger cannot buy insurance, whihc exceeds the limit
    */
    modifier requireInsuranceLessThanLimit(uint256 value) {
        require(value <= MAX_INSURANCE_LIMIT, "Value exceeds max insurance plan.");
        _;
    }
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address payable dataContract) public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
        public
        pure
        returns(bool)
    {
        return true;  // Modify to call data contract's status
    }

    function insuranceLimit() 
        public
        returns (uint256 limit)
    {
        return MAX_INSURANCE_LIMIT;
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline(address airline)
        external
        requireIsOperational
        requireAirlineIsNotYetRegistered(airline)
        requireIsAirlineFunded(msg.sender)
        returns(bool success, uint256 votes)
    {
        if(flightSuretyData.getNrOfRegisteredAirlines() <= AIRLINE_VOTING_LIMIT) {
            // Just a few airlines, we can register without voting
            flightSuretyData.registerAirline(msg.sender, airline);
            return(true, 0);
        }
        else {
            // More airlines, voting is required
            // First check for duplicate votes
            bool isDuplicate = false;
            for(uint256 i = 0; i < votingAirlines[airline].length; i++) {
                if(votingAirlines[airline][i] == msg.sender) {
                    // This airline already voted
                    isDuplicate = true;
                    // Break out from the loop
                    break;
                }
            }
            require(!isDuplicate, "This airline has already provided his vote");
            votingAirlines[airline].push(msg.sender);
            // Check if by now enough votes have been provided to complete the registration
            if(votingAirlines[airline].length.mul(AIRLINE_REGISTRATION_VOTES_REQUIRED) >= flightSuretyData.getNrOfRegisteredAirlines()) {
                // Enough votes, register airline
                flightSuretyData.registerAirline(msg.sender, airline);
                return(true, 0);
            }
            else {
                // Not enough votes yet
                return(false, votingAirlines[airline].length);
            }
        }
    }

    /**
     * @dev Fund a registered airline
     */
    function fundAirline()
        external
        payable
        requireIsOperational
        requireAirlineIsRegistered(msg.sender)
        requireAirlineNotYetFunded(msg.sender)
        requireEnoughFundingProvided()
    {
        address(uint160(address(flightSuretyData))).transfer(AIRLINE_MINIMUM_STAKE);
        flightSuretyData.fundingByAirline(msg.sender, AIRLINE_MINIMUM_STAKE);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight(string calldata flightNumber, uint256 timestamp, string calldata departure, string calldata arrival)
        external
        requireIsOperational
        requireIsAirlineFunded(msg.sender)
    {
        bytes32 flightKey = getFlightKey(msg.sender, flightNumber, timestamp);
        flightSuretyData.registerFlight(
            flightKey,
            msg.sender,
            flightNumber,
            timestamp,
            departure,
            arrival
        );
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus(address airline, string memory flightNumber, uint256 timestamp, uint8 statusCode)
        internal
        requireIsOperational
    {
        flightSuretyData.processFlightStatus(airline, flightNumber, timestamp, statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string calldata flightNumber, uint256 timestamp, bytes32 flightKey)
        external
        requireFlightIsRegistered(flightKey)
        requireFlightNotYetLanded(flightKey)
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flightNumber, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flightNumber, timestamp);
    }

    /**
    * @dev Buy insruance
    *
    */
    function buyInsurance(bytes32 flightKey)
        public
        payable
        requireIsOperational
        requireFlightIsRegistered(flightKey)
        requireFlightNotYetLanded(flightKey)
        requirePassengerNotYetInsuredForFlight(flightKey, msg.sender)
        requireInsuranceLessThanLimit(msg.value)
    {
        address(uint160(address(flightSuretyData))).transfer(msg.value);
        flightSuretyData.buyInsurance(flightKey, msg.sender, msg.value);
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay() external requireIsOperational {
            flightSuretyData.pay(msg.sender);
    }

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


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
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes() view external returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, string calldata flight, uint256 timestamp, uint8 statusCode) external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3] memory)
    {
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
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
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
    // Helpers
    function isOperational() public view returns(bool);
    function setOperatingStatus(bool mode) external;

    // Airlines§
    function registerAirline(address registeringAirline, address newAirline) external;
    function fundingByAirline(address airline, uint256 amount) external;
    function isAirlineRegistered(address airline) public view returns(bool);
    function isAirlineFunded(address airline) public view returns(bool);
    function getNrOfRegisteredAirlines() public view returns(uint256);

    // Flights
    function registerFlight(bytes32 flightKey, address airline, string memory flightNumber, uint256 timestamp,
        string memory departure, string memory arrival) public payable;
    function isFlightRegistered(bytes32 flightKey) public view returns(bool);
    function isFlightLanded(bytes32 flightKey) public view returns(bool);
    function processFlightStatus(address airline, string calldata flight, uint256 timestamp, uint8 statusCode) external;
    function isPassengerInsured(bytes32 flightKey, address passenger) public view returns(bool);

    // Insurance
    function buyInsurance(bytes32 flightKey, address passenger, uint256 amount) external payable;
    function creditInsurees(bytes32 flightKey) external;
    function pay(address payable insuree) external;
}
