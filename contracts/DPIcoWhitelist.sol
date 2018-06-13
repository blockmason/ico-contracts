pragma solidity ^0.4.24;

contract DPIcoWhitelist {
    address public admin;
    bool public isOn;
    mapping (address => bool) public whitelist;
    address[] public users;

    modifier signUpOpen() {
        if (!isOn) revert();
        _;
    }

    modifier isAdmin() {
        if (msg.sender != admin) revert();
        _;
    }

    modifier newAddr() {
        if (whitelist[msg.sender]) revert();
        _;
    }

    constructor() public {
        admin = msg.sender;
        isOn = false;
    }

    function () public {
        signUp();
    }

    // Public functions

    function setSignUpOnOff(bool state) public isAdmin {
        isOn = state;
    }

    function signUp() public signUpOpen newAddr {
        whitelist[msg.sender] = true;
        users.push(msg.sender);
    }

    function getAdmin() public constant returns (address) {
        return admin;
    }

    function signUpOn() public constant returns (bool) {
        return isOn;
    }

    function isSignedUp(address addr) public constant returns (bool) {
        return whitelist[addr];
    }

    function getUsers() public constant returns (address[]) {
        return users;
    }

    function numUsers() public constant returns (uint) {
        return users.length;
    }

    function userAtIndex(uint idx) public constant returns (address) {
        return users[idx];
    }
}
