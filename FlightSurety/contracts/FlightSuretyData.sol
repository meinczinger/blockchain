pragma solidity ^0.4.25;

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
        uint8 investedAmount;
        bool credited;
    }

    // Number of airlines registered
    uint256 registeredAirlineCount = 0;
    // Airlines
    mapping (address => Airline) private airlines;

    // Flights
    mapping (bytes32 => Flight) private flights;

    // Flight insurance claims
    mapping (bytes32 => InsuranceClaim[]) private flightInsuranceClaims;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    // Event for airline registration
    event AirlineRegistered(address airline);


    /**
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
        registeredAirlineCount = registeredAirlineCount.add(1);
        emit AirlineRegistered(newAirline);
    }


   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy
                            (
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
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

    function getFlightKey
                        (
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
    function()
                            external
                            payable
    {
    }


}
