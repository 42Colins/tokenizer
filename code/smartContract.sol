// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

error ErrorOwnerOnlyFunction();
error InvalidSignersCount();
error InvalidSignature();
error TransactionAlreadyExecuted();
error InsufficientConfirmations();
error InvalidTransaction();

contract FourtyTwoToTheMoonMultisig is ERC20, ERC20Permit {
    address public owner;
    uint256 private constant INITIAL_SUPPLY = 42_000_000 * 10**18;
    
    // Multisig parameters
    uint256 public required;
    address[] public signers;
    mapping(address => bool) public authSigners;
    
    // Transaction structure
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) confirmations;
        uint256 numConfirmations;
    }
    
    Transaction[] public waitingTransactions;
    
    // Events
    event TransactionSubmitted(uint256 indexed txIndex, address indexed from, address indexed to, uint256 value);
    event TransactionConfirmed(uint256 indexed txIndex, address indexed signer);
    event TransactionExecuted(uint256 indexed txIndex);
    
    modifier onlyOwner() {
        if (msg.sender != owner)
            revert ErrorOwnerOnlyFunction();
        _;
    }
    
    modifier onlySigner() {
        require(authSigners[msg.sender], "Not a signer");
        _;
    }
    
    modifier txExists(uint256 _txIndex) {
        require(_txIndex < waitingTransactions.length, "Transaction does not exist");
        _;
    }
    
    modifier notExecuted(uint256 _txIndex) {
        if(waitingTransactions[_txIndex].executed) revert TransactionAlreadyExecuted();
        _;
    }
    
    modifier notConfirmed(uint256 _txIndex) {
        require(!waitingTransactions[_txIndex].confirmations[msg.sender], "Already confirmed");
        _;
    }
    
    constructor(address[] memory _signers, uint256 _required) 
        ERC20("42toTheMoon", "42Moon") 
        ERC20Permit("42toTheMoon") 
    {
        if(_required == 0 || _required > _signers.length) revert InvalidSignersCount();
        
        owner = msg.sender;
        _mint(msg.sender, INITIAL_SUPPLY);
        
        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            require(signer != address(0), "Invalid signer");
            require(!authSigners[signer], "Signer not unique");
            
            authSigners[signer] = true;
            signers.push(signer);
        }
        
        required = _required;
    }
    
    function submitTransaction(address _to, uint256 _value)
        public
        onlySigner
        returns (uint256)
    {
        require(authSigners[msg.sender], "Not authorized");
        uint256 txIndex = waitingTransactions.length;
        
        waitingTransactions.push();
        Transaction storage transaction = waitingTransactions[txIndex];
        transaction.to = _to;
        transaction.value = _value;
        transaction.executed = false;
        transaction.numConfirmations = 0;
        
        emit TransactionSubmitted(txIndex, msg.sender, _to, _value);
        
        return txIndex;
    }
    
    function confirmTransaction(uint256 _txIndex)
        public
        onlySigner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = waitingTransactions[_txIndex];
        transaction.confirmations[msg.sender] = true;
        transaction.numConfirmations += 1;
        
        emit TransactionConfirmed(_txIndex, msg.sender);
    }
    
    function executeTransaction(uint256 _txIndex)
        public
        onlySigner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = waitingTransactions[_txIndex];
        
        if(transaction.numConfirmations < required) revert InsufficientConfirmations();
        
        
        // Execute the transaction
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        if(!success) revert InvalidTransaction();
        
        transaction.executed = true;
        emit TransactionExecuted(_txIndex);
    }
    
    function mint(address dest, uint256 amount) public onlyOwner {
        _mint(dest, amount);
    }
    
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    // Helper functions
    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = waitingTransactions[_txIndex];
        
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
    
    function getSigners() public view returns (address[] memory) {
        return signers;
    }
    
    function getSignerCount() public view returns (uint256) {
        return signers.length;
    }

    function addSigner(address _newSigner) external onlyOwner
    {
        authSigners[_newSigner] = true;
    }

    function removeSigner(address _signer) external onlyOwner
    {
        authSigners[_signer] = false;
    }
}