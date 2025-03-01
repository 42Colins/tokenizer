// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";


// Custom error handling
error ErrorOwnerOnlyFunction();
error InvalidSignersCount();
error InvalidSignature();
error TransactionAlreadyExecuted();
error InsufficientConfirmations();
error InvalidTransaction();


// Enum for transaction type
enum TransactionType { MINT, BURN, TRANSFER }

contract FourtyTwoToTheMoonMultisig is ERC20, ERC20Permit {
    address public owner;
    uint256 private constant INITIAL_SUPPLY = 42_000_000 * 10**18;
    
    // Multisig parameters
    uint256 public required;
    address[] public signers;
    mapping(address => bool) public authSigners;
    
    // Transaction structure : We need the sender, the receiver, the amount of token, the type of transaction, and a mapping to store signers and their number
    struct Transaction {
        address to;
        address from;
        uint256 value;
        TransactionType kind;
        bool executed;
        mapping(address => bool) confirmations;
        uint256 numConfirmations;
    }
    
    Transaction[] public waitingTransactions;
    
    // Events (for logs on bscscan)
    event TransactionSubmitted(uint256 indexed txIndex, address indexed from, address indexed to, uint256 value);
    event TransactionConfirmed(uint256 indexed txIndex, address indexed signer);
    event TransactionExecuted(uint256 indexed txIndex);
    event TransactionExecutionFailed(uint256 indexed txIndex, bytes returnData);
    
    
    // Modifiers for access control
    modifier onlyOwner() {
        if (msg.sender != owner)
            revert ErrorOwnerOnlyFunction();
        _;
    }
    
    modifier onlySigner() {
        require(authSigners[msg.sender], "Not a signer");
        _;
    }
    // Modifiers for transaction error handling
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
        
        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            require(signer != address(0), "Invalid signer");
            require(!authSigners[signer], "Signer not unique");
            
            authSigners[signer] = true;
            signers.push(signer);
        }
        
        required = _required;
    }
    
    // Record the transaction in the waitingTransactions array
    function submitTransaction(address _to, uint256 _value, TransactionType _type)
        public
        onlySigner
        returns (uint256)
    {
        if (_type == TransactionType.TRANSFER || _type == TransactionType.BURN)
            require(balanceOf(address(_to)) >= _value, "Insuficient funds !");
        require(authSigners[msg.sender], "Not authorized");
        uint256 txIndex = waitingTransactions.length;
        
        waitingTransactions.push();
        Transaction storage transaction = waitingTransactions[txIndex];
        transaction.to = _to;
        transaction.value = _value;
        transaction.executed = false;
        transaction.numConfirmations = 0;
        transaction.kind = _type;
        transaction.from = msg.sender;
        
        emit TransactionSubmitted(txIndex, msg.sender, _to, _value);
        
        return txIndex;
    }
    
    
    // Confirm a transaction based on its index (only one signer at a time)
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
    
    
    // Execute the transaction if the required number of confirmations is reached
    function executeTransaction(uint256 _txIndex)
        public
        onlySigner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = waitingTransactions[_txIndex];
        
        if(transaction.numConfirmations < required) revert InsufficientConfirmations();
                
        if (transaction.kind == TransactionType.MINT)
            _mint(transaction.to, transaction.value);
        else if (transaction.kind == TransactionType.BURN)
            _burn(transaction.to, transaction.value);
        else if (transaction.kind == TransactionType.TRANSFER)
            _transfer(address(transaction.from), transaction.to, transaction.value);

        transaction.executed = true;
        emit TransactionExecuted(_txIndex);
    }
    
    
    // Base ERC20 functions
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
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = waitingTransactions[_txIndex];
        
        return (
            transaction.to,
            transaction.value,
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


    // Add and remove signers
    function addSigner(address _newSigner) external onlyOwner
    {
        authSigners[_newSigner] = true;
        signers.push(_newSigner);

    }

    function removeSigner(address _signer) external onlyOwner
    {
        authSigners[_signer] = false;
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
    }
}