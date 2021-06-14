pragma solidity ^0.5.10;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    // Minimum stake required by airlines to get registered
    uint256 private constant MIN_FUNDING = 100;

    // Insurance premium
    uint256 private constant INSURANCE_PREMIUM_PERCENTAGE = 120;

    // Structure representing an airline
    struct Airline {
        bool registered;
        bool funded;
    }

    // Structure representing a flight
    struct Flight {
        bool registered;
        address airline;
        bytes32 key;
        string flightNumber;
        uint8 status;
        uint256 timestamp;
        string departure;
        string arrival;
    }

    // Structure representing claims
    struct InsuranceClaim {
        address passenger;
        uint256 investedAmount;
        bool credited;
    }

    // Airlines
    mapping (address => Airline) private airlines;

    // Number of airlines registered
    uint256 nrOfAirlines = 0;

    // Flights
    mapping (bytes32 => Flight) private flights;

    // Flight insurance claims
    mapping (bytes32 => InsuranceClaim[]) private flightInsuranceClaims;

    // Approved insurance payout for passengers
    mapping (address => uint256) private creditedFunds;

    // Registereed flights
    bytes32[] private registeredFlights;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    // Event for airline registration
    event AirlineRegistered(address airline);

    // Event for flight registration
    event FlightRegistered(bytes32 key);

    // Event for purchasing insurance
    event PassengerBoughtInsurance(bytes32 flightKey, address passenger, uint256 amount);

    // Event for crediting insurees
    event InsureeCredited(bytes32 flightKey, address passenger, uint256 amount);

    // Event for insuree payout
    event InsureePaid(address insuree, uint256);

    // Event for processing flight status
    event ProcessedFlightStatus(bytes32 flightKey, uint8 status);

    /*
    * @dev Constructor
    *      The deploying account becomes contractOwner
    *      Input: address of the first airline
    */
    constructor(address airline) public payable {
        contractOwner = msg.sender;
        airlines[airline] = Airline(true, false);
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

    /**
    * @dev Modifier that requires that the airline is not yet registered (to avoid double-registration and wasting gas)
    */
    modifier requireAirlineNotYetRegistered(address airline) {
        require(!airlines[airline].registered, "Airline has been already registered");
        _;
    }

    /**
    * @dev Modifier that requires that the airline is already registered
    */
    modifier requireAirlineIsRegistered(address airline) {
        require(airlines[airline].registered, "Airline has not yet been registered");
        _;
    }

    /**
    * @dev Modifier that requires the airline provided funding. This is used for both the registration as well for voting
    */
    modifier requireAirlineProvidedFunding(address airline) {
        require(airlines[airline].funded, "Airline must provide funding in order to be able to register and vote");
        _;
    }

    /**
    * @dev Modifier that requires the airline has not yet provided funding.
    */
    modifier requireAirlineNoFunding(address airline) {
        require(!airlines[airline].funded, "Airline alerady has provided funding");
        _;
    }

    /**
    * @dev Modifier that requires the airline to provide at least as much as the minimum fundig required.
    */
    modifier requireMinimumFunding(uint256 value) {
        require(value >= MIN_FUNDING, "Funds provided are not sufficients");
        _;
    }

    /**
    * @dev Modifier that requires that the flight is not yet registered (to avoid double-registration and wasting gas)
    */
    modifier requireFlightNotYetRegistered(bytes32 key) {
        require(!flights[key].registered, "Flight has been already registered");
        _;
    }

    /**
    * @dev Modifier that requires that the flight has been already registered
    */
    modifier requireFlightIsRegistered(bytes32 key) {
        require(flights[key].registered, "Flight has not yet been registered");
        _;
    }

    /**
    * @dev Modifier that requires that insurance exists for a given flight
    */
    modifier requireInsuranceExistsForFlight(bytes32 flightKey) {
        require(flightInsuranceClaims[flightKey].length > 0, "There is no insurance for this flight");
        _;
    }

    /**
    * @dev Modifier that requires that the address has creditable funds
    */
    modifier requireAddressHasCreditableFunds(address insuree) {
        require(creditedFunds[insuree] > 0, "Address has no credit");
        _;
    }

    /**
    * @dev Modifier that requires that this contract has enough funds to credit an insuree
    */
    modifier requireContractHasEnoughFunds(uint256 amount) {
        require(address(this).balance >= amount, "Contract does not have enough balance to credit insuree");
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
    function isOperational() public view returns(bool) {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /**
    * @dev Check if the airline is already registered
    * @return Airline registered (true/false)
    */
    function isAirlineRegistered(address airline) public view requireIsOperational returns(bool) {
        return airlines[airline].registered;
    }

    /**
    * @dev Check if airline is already funded
    * @return Airline funded (true/false)
    */
    function isAirlineFunded(address airline) public view returns(bool) {
        return airlines[airline].funded;
    }

    /**
    * @dev Check if flight is registered
    * @return Airline Registered (true/false)
    */
    function isFlightRegistered(bytes32 flightKey) public view returns(bool) {
        return flights[flightKey].registered;
    }

    /**
    * @dev Check if flight has landed
    * @return Status if flight landed (true/false)
    */
    function isFlightLanded(bytes32 flightKey) public view returns(bool) {
        if (flights[flightKey].status > 0) {
            return true;
        }
        return false;
    }

    /**
     * @dev Get the number of airlines already registered
     * @return Number of registered airlines
     */
    function getNrOfRegisteredAirlines() public view requireIsOperational returns(uint256) {
        return nrOfAirlines;
    }

    /**
     * @dev Check, if a passenger is already insured
     * @return True if passenger is already insured, otherwise false
     */
    function isPassengerInsured(bytes32 flightKey, address passenger) public view returns(bool) {
        InsuranceClaim[] memory insuranceClaims = flightInsuranceClaims[flightKey];
        for (uint256 i = 0; i < insuranceClaims.length; i++) {
            if (insuranceClaims[i].passenger == passenger) {
                // Passenger found, return true (and break)
                return true;
            }
        }
        // Passenger not yet insured
        return false;
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *       Input: one of the already registered airlines and a new airline
    *
    */
    function registerAirline(address registeringAirline, address newAirline)
        external
        requireIsOperational
        requireAirlineNotYetRegistered(newAirline)
        requireAirlineProvidedFunding(registeringAirline)
    {
        airlines[newAirline] = Airline(true, false);
        nrOfAirlines = nrOfAirlines.add(1);
        emit AirlineRegistered(newAirline);
    }

    /**
     * @dev Register a flight
     *       Input:
     *          - Flight key
     *          - Airline
     *          - Flight number
     *          - Timestamp
     *          - Departure
     *          - Arrival§
     *
     */
    function registerFlight(bytes32 flightKey, address airline, string memory flightNumber, uint256 timestamp,
        string memory departure, string memory arrival)
        public
        payable
        requireIsOperational
        requireAirlineProvidedFunding(airline)
        requireFlightNotYetRegistered(flightKey)
    {
        flights[flightKey] = Flight(true, airline, flightKey, flightNumber, 0, timestamp, departure, arrival);
        registeredFlights.push(flightKey);
        emit FlightRegistered(flightKey);
    }

    /**
     * @dev Buy insurance for a flight
     *   Input:
     *       - Airline
     *       - Flight number
     *       - Timestamp
     *       - Flight statua
     *
     */
    function processFlightStatus(address airline, string calldata flight, uint256 timestamp, uint8 statusCode)
        external requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(!isFlightLanded(flightKey), "Flight has already landed.");
        if (flights[flightKey].status == 0) {
            flights[flightKey].status = statusCode;
            if (statusCode == 20) {
                creditInsurees(flightKey);
            }
        }
        emit ProcessedFlightStatus(flightKey, statusCode);
    }

   /**
    * @dev Buy insurance for a flight
    *   Input:
    *       - Flight key
    *       - Passenger
    *       - Amount
    *
    */
    function buyInsurance(bytes32 flightKey, address passenger, uint256 amount)
        external
        payable
        requireIsOperational
        requireFlightIsRegistered(flightKey)
    {
        flightInsuranceClaims[flightKey].push(InsuranceClaim(passenger, amount, false));
        emit PassengerBoughtInsurance(flightKey, passenger, amount);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(bytes32 flightKey)
        internal
        requireIsOperational
        requireInsuranceExistsForFlight(flightKey)
    {
        for(uint256 i = 0; i < flightInsuranceClaims[flightKey].length; i++) {
            InsuranceClaim memory insuranceClaim = flightInsuranceClaims[flightKey][i];
            insuranceClaim.credited = true;
            uint256 creditAmount = insuranceClaim.investedAmount.mul(INSURANCE_PREMIUM_PERCENTAGE).div(100);
            creditedFunds[insuranceClaim.passenger] = creditedFunds[insuranceClaim.passenger].add(creditAmount);
            emit InsureeCredited(flightKey, insuranceClaim.passenger, creditAmount);
        }
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address payable insuree)
        external
        payable
        requireIsOperational
        requireAddressHasCreditableFunds(insuree)
        requireContractHasEnoughFunds(creditedFunds[insuree])
    {
        uint256 amount = creditedFunds[insuree];
        creditedFunds[insuree] = 0;
        address(uint160(address(insuree))).transfer(amount);
        emit InsureePaid(insuree, amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fundingByAirline(address airline, uint256 amount)
            external
            requireIsOperational
            requireAirlineIsRegistered(airline)
            requireAirlineNoFunding(airline)
            requireMinimumFunding(amount)
    {
        airlines[airline].funded = true;

    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp)
        internal
        pure
        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
    }


}
