
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;

    const MAX_INSURANCE_LIMIT = 1;

    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeApp(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    describe('Helper test suite', function () {
        it(`(multiparty) has correct initial isOperational() value`, async function () {

            // Get operating status
            let status = await config.flightSuretyData.isOperational.call();
            assert.equal(status, true, "Incorrect initial operating status value");

        });

        it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

            // Ensure that access is denied for non-Contract Owner account
            let accessDenied = false;
            try {
                await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
            }
            catch (e) {
                accessDenied = true;
            }
            assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

        });

        it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

            // Ensure that access is allowed for Contract Owner account
            let accessDenied = false;
            try {
                await config.flightSuretyData.setOperatingStatus(false);
            }
            catch (e) {
                accessDenied = true;
            }
            assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

        });

        it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

            await config.flightSuretyData.setOperatingStatus(false);

            let reverted = false;
            try {
                await config.flightSurety.setTestingMode(true);
            }
            catch (e) {
                reverted = true;
            }
            assert.equal(reverted, true, "Access not blocked for requireIsOperational");

            // Set it back for other tests to work
            await config.flightSuretyData.setOperatingStatus(true);

        });
    });

    describe('Airline test suite', function () {
        describe('Register an airline without funding', function () {
            it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

                // ARRANGE
                let newAirline = config.restOfAddresses[0];

                // ACT
                try {
                    await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
                }
                catch (e) {

                }
                let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

                // ASSERT
                assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

            });
        });

        it('(airline) cannot be registered more than once', async () => {

            // ARRANGE
            let newAirline = config.restOfAddresses[0];
            // flag to capture exception
            let exception_caught = false;

            // ACT
            try {
                await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
                // Register the same airline once more
                await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
            }
            catch (e) {
                exception_caught = true;
            }

            // ASSERT
            assert.equal(exception_caught, true, "The same airline cannot be registered twice");

        });
    })
    describe('Passenger test suite', function () {
        it('(passanger) cannot buy insurance for more than the defined limit (MAX_INSURANCE_LIMIT)', async () => {
            let airline = config.restOfAddresses[0];
            let passanger = config.restOfAddresses[1];
            // Get the configured limit
            let amount = await config.flightSuretyApp.insuranceLimit.call();
            let convertedAmount = web3.utils.toWei(amount.toString(), "ether");
            // Add one wei to the limit
            convertedAmount = convertedAmount + 1;
            // flag to capture exception
            let exception_caught = false;

            try {
                await config.flightSuretyApp.buyInsurance(0, {from: passenger, value: convertedAmount})
            } 
            catch (e) {
                exception_caught = true;
            }

            // ASSERT
            assert.equal(exception_caught, true, "No passenger can pay more than 1 ether");
        });
    });
});
