// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { ContractGuard } from "../lib/ContractGuard.sol";
import { FlowInsightERC721NFT } from "../nft/FlowInsightERC721NFT.sol";

/*
    Copyright 2016, Jordi Baylina

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/// @title Vault Contract
/// @author Jordi Baylina
/// @notice This contract holds funds for Campaigns and automates payments. For
///  this iteration the funds will come straight from the Giveth Multisig as a
///  safety precaution, but once fully tested and optimized this contract will
///  be a safe place to store funds equipped with optional variable time delays
///  to allow for an optional escape hatch

/// @dev `Owned` is a base level contract that assigns an `owner` that can be
///  later changed
contract Owned {
    /// @dev `owner` is the only address that can call a function with this
    /// modifier
    modifier onlyOwner { 
        require(msg.sender == owner, "not owner"); 
        _; 
    }

    address public owner;

    /// @notice The Constructor assigns the message sender to be `owner`
    constructor() { owner = msg.sender;}

    /// @notice `owner` can step down and assign some other address to this role
    /// @param _newOwner The address of the new owner. 0x0 can be used to create
    ///  an unowned neutral vault, however that cannot be undone
    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
        emit NewOwner(msg.sender, _newOwner);
    }

    event NewOwner(address indexed oldOwner, address indexed newOwner);
}
/// @dev `Escapable` is a base level contract built off of the `Owned`
///  contract that creates an escape hatch function to send its ether to
///  `escapeHatchDestination` when called by the `escapeHatchCaller` in the case that
///  something unexpected happens
contract Escapable is Owned {
    address public escapeHatchCaller;
    address public escapeHatchDestination;

    /// @notice The Constructor assigns the `escapeHatchDestination` and the
    ///  `escapeHatchCaller`
    /// @param _escapeHatchDestination The address of a safe location (usu a
    ///  Multisig) to send the ether held in this contract
    /// @param _escapeHatchCaller The address of a trusted account or contract to
    ///  call `escapeHatch()` to send the ether in this contract to the
    ///  `escapeHatchDestination` it would be ideal that `escapeHatchCaller` cannot move
    ///  funds out of `escapeHatchDestination`
    constructor(address _escapeHatchCaller, address _escapeHatchDestination) {
        escapeHatchCaller = _escapeHatchCaller;
        escapeHatchDestination = _escapeHatchDestination;
    }

    /// @dev The addresses preassigned the `escapeHatchCaller` role
    ///  is the only addresses that can call a function with this modifier
    modifier onlyEscapeHatchCallerOrOwner {
        require (msg.sender == escapeHatchCaller || msg.sender == owner, "not escape hatch caller or owner");
        _;
    }

    /// @notice The `escapeHatch()` should only be called as a last resort if a
    /// security issue is uncovered or something unexpected happened
    function escapeHatch() onlyEscapeHatchCallerOrOwner public {
        uint total = address(this).balance;
        // Send the total balance of this contract to the `escapeHatchDestination`
        require (payable(escapeHatchDestination).send(total));
        emit EscapeHatchCalled(total);
    }
    /// @notice Changes the address assigned to call `escapeHatch()`
    /// @param _newEscapeHatchCaller The address of a trusted account or contract to
    ///  call `escapeHatch()` to send the ether in this contract to the
    ///  `escapeHatchDestination` it would be ideal that `escapeHatchCaller` cannot
    ///  move funds out of `escapeHatchDestination`
    function changeEscapeCaller(address _newEscapeHatchCaller) onlyEscapeHatchCallerOrOwner public {
        escapeHatchCaller = _newEscapeHatchCaller;
    }

    event EscapeHatchCalled(uint amount);
}

/// @dev `Vault` is a higher level contract built off of the `Escapable`
///  contract that holds funds for Campaigns and automates payments.
contract FlowInsightVault is Escapable, ContractGuard {

    /// @dev `Payment` is a public structure that describes the details of
    ///  each payment making it easy to track the movement of funds
    ///  transparently
    struct Payment {
        address payable buyer;        // Who is making the payments
        uint earliestPayTime;   // The earliest a payment can be made (Unix Time)
        bool canceled;         // If True then the payment has been canceled
        bool paid;              // If True then the payment has been paid
        address payable recipient;      // Who is receiving the payment
        address token;          // address(0) when purchase with ETH
        uint amount;            // The amount of wei sent in the payment
        uint securityGuardDelay;// The seconds `securityGuard` can delay payment
    }

    Payment[] public authorizedPayments;

    address public securityGuard;
    uint public absoluteMinTimeLock;
    uint public timeLock;
    uint public maxSecurityGuardDelay;

    /// @dev The white list of approved addresses allowed to set up && receive
    ///  payments from this vault
    mapping (address => bool) public allowedMarketplace;

    modifier onlyAllowedMarketplace { 
        require(allowedMarketplace[msg.sender], "not allowed marketplace"); 
        _; 
    }

    /// @dev The address assigned the role of `securityGuard` is the only
    ///  addresses that can call a function with this modifier
    modifier onlySecurityGuard { 
        require (msg.sender == securityGuard, "not security guard"); 
        _; 
    }

    // @dev Events to make the payment movements easy to find on the blockchain
    event PaymentAuthorized(uint indexed idPayment, address indexed recipient, address token, uint amount);
    event PaymentExecuted(uint indexed idPayment, address indexed recipient, address token, uint amount);
    event PaymentCanceled(uint indexed idPayment);
    event EtherReceived(address indexed from, uint amount);
    event MarketplaceAuthorization(address indexed marketplace, bool authorized);

/////////
// Constructor
/////////

    /// @notice The Constructor creates the Vault on the blockchain
    /// @param _escapeHatchCaller The address of a trusted account or contract to
    ///  call `escapeHatch()` to send the ether in this contract to the
    ///  `escapeHatchDestination` it would be ideal if `escapeHatchCaller` cannot move
    ///  funds out of `escapeHatchDestination`
    /// @param _escapeHatchDestination The address of a safe location (usu a
    ///  Multisig) to send the ether held in this contract in an emergency
    /// @param _absoluteMinTimeLock The minimum number of seconds `timelock` can
    ///  be set to, if set to 0 the `owner` can remove the `timeLock` completely
    /// @param _timeLock Initial number of seconds that payments are delayed
    ///  after they are authorized (a security precaution)
    /// @param _securityGuard Address that will be able to delay the payments
    ///  beyond the initial timelock requirements; can be set to 0x0 to remove
    ///  the `securityGuard` functionality
    /// @param _maxSecurityGuardDelay The maximum number of seconds in total
    ///   that `securityGuard` can delay a payment so that the owner can cancel
    ///   the payment if needed
    constructor(
        address _escapeHatchCaller,
        address _escapeHatchDestination,
        uint _absoluteMinTimeLock,
        uint _timeLock,
        address _securityGuard,
        uint _maxSecurityGuardDelay) Escapable(_escapeHatchCaller, _escapeHatchDestination)
    {
        absoluteMinTimeLock = _absoluteMinTimeLock;
        timeLock = _timeLock;
        securityGuard = _securityGuard;
        maxSecurityGuardDelay = _maxSecurityGuardDelay;
    }

/////////
// Helper functions
/////////

    /// @notice States the total number of authorized payments in this contract
    /// @return The number of payments ever authorized even if they were canceled
    function numberOfAuthorizedPayments() public view onlyEscapeHatchCallerOrOwner returns (uint) {
        return authorizedPayments.length;
    }

    function getBalance() public view onlyEscapeHatchCallerOrOwner returns (uint256) {
        return address(this).balance;
    }

//////
// Receive Ether
//////

    /// @notice Called anytime ether is sent to the contract && creates an event
    /// to more easily track the incoming transactions
    function receiveEther() public payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /// @notice The fall back function is called whenever ether is sent to this
    ///  contract
    receive () external payable {
        receiveEther();
    }

////////
// Marketplace Interface
////////

    /// @notice only `allowedMarketplace[]` Creates a new `Payment`
    /// @param _recipient Destination of the payment
    /// @param _amount Amount to be paid in wei
    /// @param _paymentDelay Number of seconds the payment is to be delayed, if
    ///  this value is below `timeLock` then the `timeLock` determines the delay
    /// @return The Payment ID number for the new authorized payment
    function authorizePayment(
        address _buyer,
        address _recipient,
        uint _amount,
        uint _paymentDelay
    ) public onlyAllowedMarketplace returns(uint) {

        uint idPayment = authorizedPayments.length;       // Unique Payment ID

        // Overflow protection
        require (_paymentDelay <= 10**18);

        // The following lines fill out the payment struct
        Payment memory p = Payment({
            buyer: payable(_buyer), 
            earliestPayTime: _paymentDelay >= timeLock ?
                                block.timestamp + _paymentDelay :
                                block.timestamp + timeLock,
            canceled: false,
            paid: false,
            recipient: payable(_recipient),
            token: address(0),
            amount: _amount,
            securityGuardDelay: 0
        });
      
        authorizedPayments.push(p);
        emit PaymentAuthorized(idPayment, p.recipient, p.token, p.amount);
        return idPayment;
    }

    /// @notice only `allowedMarketplace[]` The recipient of a payment calls this
    ///  function to send themselves the ether after the `earliestPayTime` has
    ///  expired
    /// @param _idPayment The payment ID to be executed
    function collectAuthorizedPayment(uint _idPayment) public onlyAllowedMarketplace {

        // Check that the `_idPayment` has been added to the payments struct
        require (_idPayment < authorizedPayments.length, "invalid payment id");

        Payment storage p = authorizedPayments[_idPayment];

        // Checking for reasons not to execute the payment
        require (block.timestamp >= p.earliestPayTime);
        require (!p.canceled, "payment is canceled");
        require (!p.paid, "payment is paid");
        require (address(this).balance >= p.amount, "insufficient balance");

        p.paid = true; // Set the payment to being paid
        require (p.recipient.send(p.amount)); // Make the payment
        emit PaymentExecuted(_idPayment, p.recipient, p.token, p.amount);
    }

    function transferNFT(uint256 _nftId, uint _idPayment, address _flowInsightNFT) public onlyAllowedMarketplace {
        require (_idPayment < authorizedPayments.length, "invalid payment id");

        Payment memory p = authorizedPayments[_idPayment];
        FlowInsightERC721NFT(_flowInsightNFT).safeTransferFrom(p.recipient, p.buyer, _nftId);
    }
    
    /// @notice only `buyer` or `allowedMarketplace[]` or `securityGuard` Cancel and return a payment
    /// @param _idPayment ID of the payment to be canceled.
    function cancelPayment(uint _idPayment) public onlyOneBlock {
        require (_idPayment < authorizedPayments.length);

        Payment storage p = authorizedPayments[_idPayment];

        // Checking msg sender 
        require (msg.sender == p.buyer || allowedMarketplace[msg.sender] || msg.sender == securityGuard, 
                    "not buyer or allowed marketplace or security guard"); 
        require (!p.canceled, "payment is canceled");
        require (!p.paid, "payment is paid");

        p.canceled = true; // Set the payment to being canceled
        require (p.buyer.send(p.amount)); // Return the payment
        emit PaymentCanceled(_idPayment);
    }

/////////
// SecurityGuard Interface
/////////

    /// @notice `onlySecurityGuard` Delays a payment for a set number of seconds
    /// @param _idPayment ID of the payment to be delayed
    /// @param _delay The number of seconds to delay the payment
    function delayPayment(uint _idPayment, uint _delay) public onlySecurityGuard {
        require (_idPayment < authorizedPayments.length);

        // Overflow test
        require (_delay <= 10**18);

        Payment storage p = authorizedPayments[_idPayment];

        require ((p.securityGuardDelay + _delay <= maxSecurityGuardDelay) && !p.paid && !p.canceled);

        p.securityGuardDelay += _delay;
        p.earliestPayTime += _delay;
    }

////////
// Owner Interface
///////

    /// @notice `onlyOwner` Adds a marketplace to the `allowedMarketplace[]` white list
    /// @param _marketplace The address of the contract being authorized/unauthorized
    /// @param _authorize `true` if authorizing and `false` if unauthorizing
    function authorizeMarketplace(address _marketplace, bool _authorize) public onlyOwner {
        allowedMarketplace[_marketplace] = _authorize;
        emit MarketplaceAuthorization(_marketplace, _authorize);
    }

    /// @notice `onlyOwner` Sets the address of `securityGuard`
    /// @param _newSecurityGuard Address of the new security guard
    function setSecurityGuard(address _newSecurityGuard) public onlyOwner {
        securityGuard = _newSecurityGuard;
    }

    /// @notice `onlyOwner` Changes `timeLock`; the new `timeLock` cannot be
    ///  lower than `absoluteMinTimeLock`
    /// @param _newTimeLock Sets the new minimum default `timeLock` in seconds;
    ///  pending payments maintain their `earliestPayTime`
    function setTimelock(uint _newTimeLock) public onlyOwner {
        require (_newTimeLock >= absoluteMinTimeLock);
        timeLock = _newTimeLock;
    }

    /// @notice `onlyOwner` Changes the maximum number of seconds
    /// `securityGuard` can delay a payment
    /// @param _maxSecurityGuardDelay The new maximum delay in seconds that
    ///  `securityGuard` can delay the payment's execution in total
    function setMaxSecurityGuardDelay(uint _maxSecurityGuardDelay) public onlyOwner {
        maxSecurityGuardDelay = _maxSecurityGuardDelay;
    }
}
