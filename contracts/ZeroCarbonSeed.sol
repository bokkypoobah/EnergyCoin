/*
file:   ZeroCarbonSeed.sol
ver:    0.1.0
author: Darryl Morris
date:   28-Aug-2017
email:  o0ragman0o AT gmail.com
(c) Darryl Morris 2017

A collated contract set for a token prefund specific to the requirments of
Beond's ZeroCarbon green energy subsidy token.

This presale token (ZCS) pegs generated tokens against ether 3:1 which gives
holders 3x buying power over ether at the time of the NRG production token
launch in 2018.

Upon a successful NRG token ICO, ZCS token transfers are halted and tokens can
only be migrated to the ZCS contract via an intercontract token transfer
mechanism.

This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See MIT Licence for further details.
<https://opensource.org/licenses/MIT>.

Release Notes
-------------
0.1.0

1350 ether being raised at 3:1 token ratio.  These tokens will be transferable
to the future production royalties token at 1:1.

+-+- Opens 1 November 2017. 3x tokens
|
|
|
+-+- 1 Close 22 November 2017 || minted <= 1350
| +- Funds to round 1 fund wallet
| +- 1% to commision wallt
|
+-+- Round 2. Production token. Open 8th January 2018. 1x tokens
| +- mint 10,000,000 tokens to Beond wallets
| +- Transfer round 1 tokens at 3:1
|
|
+-+- Round 2 Close 6th February 2018 || minted <= 4,000,000
| +- Funds to round 2 fund wallet
| +- 1% to commission wallet
| +- Open trading
|
+--- < 4 years 4x coin mint / MWh
|
+--- > 4 years 1x coin minted / MWh

*/


pragma solidity ^0.4.13;

/*-----------------------------------------------------------------------------\

 Ventana token sale configuration

\*----------------------------------------------------------------------------*/

// Contains token sale parameters
contract ZeroCarbonSeedConfig
{
    // ERC20 trade name and symbol
    string public           name            = "ZeroCarbon Seed";
    string public           symbol          = "ZCS";

    // Owner has power to abort, discount addresses, sweep successful funds,
    // change owner, sweep alien tokens.
    address public          owner           = msg.sender; //0x0;
    
    // Fund wallet should also be audited prior to deployment
    // NOTE: Must be checksummed address!
    address public          fundWallet      = msg.sender; //0x0;
    // ICO developer commisions wallet (1% of funds raised)
    address public          devWallet       = msg.sender; //0x0;

    // Token/Eth ratio
    uint public constant    TOKENS_PER_ETH  = 3;
    
    // USD per NRG in cents
    uint public constant    CENTS_PER_NRG   = 150;
    
    // Minimum and maximum target in USD
    uint public constant    MIN_ETH_FUND    = 675 * 1 ether; // ~$250,000
    uint public constant    MAX_ETH_FUND    = 1350 * 1 ether; // ~$500,000
    
    // Funding begins on 1st November 2017
    // `+ new Date('00:00 1 November 2017')/1000`
    // uint public constant    START_DATE      = 1509458400;
    uint public constant    START_DATE      = 1504143469;

    // Period for fundraising
    uint public constant    FUNDING_PERIOD  = 21 days;
}


library SafeMath
{
    // a add to b
    function add(uint a, uint b) internal returns (uint c) {
        c = a + b;
        assert(c >= a);
    }
    
    // a subtract b
    function sub(uint a, uint b) internal returns (uint c) {
        c = a - b;
        assert(c <= a);
    }
    
    // a multiplied by b
    function mul(uint a, uint b) internal returns (uint c) {
        c = a * b;
        assert(a == 0 || c / a == b);
    }
    
    // a divided by b
    function div(uint a, uint b) internal returns (uint c) {
        c = a / b;
        // No assert required as no overflows are posible.
    }
}


contract ReentryProtected
{
    // The reentry protection state mutex.
    bool __reMutex;

    // Sets and resets mutex in order to block functin reentry
    modifier preventReentry() {
        require(!__reMutex);
        __reMutex = true;
        _;
        delete __reMutex;
    }

    // Blocks function entry if mutex is set
    modifier noReentry() {
        require(!__reMutex);
        _;
    }
}

contract ERC20Token
{
    using SafeMath for uint;

/* Constants */

    // none
    
/* State variable */

    /// @return The Total supply of tokens
    uint public totalSupply;
    
    /// @return Token symbol
    string public symbol;
    
    // Token ownership mapping
    mapping (address => uint) balances;
    
    // Allowances mapping
    mapping (address => mapping (address => uint)) allowed;

/* Events */

    // Triggered when tokens are transferred.
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _amount);

    // Triggered whenever approve(address _spender, uint256 _amount) is called.
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _amount);

/* Modifiers */

    // none
    
/* Functions */

    // Using an explicit getter allows for function overloading    
    function balanceOf(address _addr)
        public
        constant
        returns (uint)
    {
        return balances[_addr];
    }
    
    // Using an explicit getter allows for function overloading    
    function allowance(address _owner, address _spender)
        public
        constant
        returns (uint)
    {
        return allowed[_owner][_spender];
    }

    // Send _value amount of tokens to address _to
    function transfer(address _to, uint256 _amount)
        public
        returns (bool)
    {
        return xfer(msg.sender, _to, _amount);
    }

    // Send _value amount of tokens from address _from to address _to
    function transferFrom(address _from, address _to, uint256 _amount)
        public
        returns (bool)
    {
        require(_amount <= allowed[_from][msg.sender]);
        
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        return xfer(_from, _to, _amount);
    }

    // Process a transfer internally.
    function xfer(address _from, address _to, uint _amount)
        internal
        returns (bool)
    {
        require(_amount <= balances[_from]);

        Transfer(_from, _to, _amount);
        
        // avoid wasting gas on 0 token transfers
        if(_amount == 0) return true;
        
        balances[_from] = balances[_from].sub(_amount);
        balances[_to]   = balances[_to].add(_amount);
        
        return true;
    }

    // Approves a third-party spender
    function approve(address _spender, uint256 _amount)
        public
        returns (bool)
    {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }
}


/*-----------------------------------------------------------------------------\

## Conditional Entry Table

Functions must throw on F conditions

Conditional Entry Table (functions must throw on F conditions)

renetry prevention on all public mutating functions
Reentry mutex set in moveFundsToWallet(), refund()

|function                |<START_DATE|<END_DATE |fundFailed  |fundSucceeded|icoSucceeded
|------------------------|:---------:|:--------:|:----------:|:-----------:|:---------:|
|()                      |F          |T         |F           |T            |F          |
|abort()                 |T          |T         |T           |T            |F          |
|proxyPurchase()         |F          |T         |F           |T            |F          |
|finaliseICO()           |F          |F         |F           |T            |T          |
|refund()                |F          |F         |T           |F            |F          |
|transfer()              |F          |F         |F           |F            |T          |
|transferFrom()          |F          |F         |F           |F            |T          |
|approve()               |F          |F         |F           |F            |T          |
|changeOwner()           |T          |T         |T           |T            |T          |
|acceptOwnership()       |T          |T         |T           |T            |T          |
|changeUtlity()          |T          |T         |T           |T            |T          |
|destroy()               |F          |F         |!__abortFuse|F            |F          |
|transferAnyERC20Tokens()|T          |T         |T           |T            |T          |

\*----------------------------------------------------------------------------*/

contract ZeroCarbonSeedAbstract
{
// TODO comment events
    // Triggered when a refund is claimed
    event Refunded(address indexed _addr, uint indexed _value);
    
    // Triggered upon change of owner
    event ChangedOwner(address indexed _from, address indexed _to);
    
    // Triggered upon initiation a change of ownership
    event ChangeOwnerTo(address indexed _to);
    
    // Triggered upon ether leaving the contract
    event FundsTransferred(address indexed _wallet, uint indexed _value);
    
    // Triggered upon transferring tokens to the production contract.
    event MigratedTo(address indexed _from, address indexed _to, uint indexed _amount);

    // This fuse blows upon calling abort() which forces a fail state
    bool public __abortFuse = true;
    
    // Set to true after the fund is swept to the fund wallet, allows token
    // transfers and prevents abort()
    bool public icoSuccessful;
    
    // Set to true by NRG ICO contract upon finalisation
    bool public mustMigrate;

    // Token conversion factors are calculated with decimal places at parity with ether
    uint8 public constant decimals = 18;

    // An address authorised to take ownership
    address public newOwner;
    
    // The future NRG production token address
    address public nrgAddr;
    
    // Total ether raised during funding
    uint public etherRaised;
    
    // Record of ether paid per address
    mapping (address => uint) public etherContributed;

    // Return `true` if MIN_FUNDS were raised
    function fundSucceeded() public constant returns (bool);
    
    // Return `true` if MIN_FUNDS were not raised before END_DATE
    function fundFailed() public constant returns (bool);
    
    // Returns token/ether conversion given ether value and address. 
    function ethToTokens(uint _eth)
        public constant returns (uint);

    // Processes a token purchase for a given address
    function proxyPurchase(address _addr) payable returns (bool);

    // Owner can move funds of successful fund to fundWallet 
    function finaliseICO() public returns (bool);

    // Called by NRG contract to halt transfers and open migration.
    function setMigrate() public returns (bool);

    // To migrate ZCS tokens to NRG tokens
    function migrate(address _addr) public returns (bool);
    
    // Refund on failed or aborted sale 
    function refund(address _addr) public returns (bool);

    // To cancel token sale prior to START_DATE
    function abort() public returns (bool);
    
    // Change the Veredictum backend contract address
    function setNRG(address _addr) public returns (bool);
    
    // For owner to salvage tokens sent to contract
    function transferAnyERC20Token(address tokenAddress, uint amount)
        returns (bool);
}


/*-----------------------------------------------------------------------------\

ZeroCarbonSeed token implimentation

\*----------------------------------------------------------------------------*/

contract ZeroCarbonSeedToken is 
    ReentryProtected,
    ERC20Token,
    ZeroCarbonSeedAbstract,
    ZeroCarbonSeedConfig
{
    using SafeMath for uint;

//
// Constants
//

    // General funding opens LEAD_IN_PERIOD after deployment (timestamps can't be constant)
    uint public END_DATE = START_DATE + FUNDING_PERIOD;
    
    uint public MAX_TOKENS = MAX_ETH_FUND * TOKENS_PER_ETH;

//
// Modifiers
//

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

//
// Functions
//

    // Constructor
    function ZeroCarbonSeedToken()
    {
        // ICO parameters are set in VentanaTSConfig
        // Invalid configuration catching here
        require(bytes(symbol).length > 0);
        require(bytes(name).length > 0);
        require(owner != 0x0);
        require(fundWallet != 0x0);
        require(devWallet != 0x0);
        require(TOKENS_PER_ETH > 0);
        require(MIN_ETH_FUND > 0);
        require(MAX_ETH_FUND > MIN_ETH_FUND);
        require(START_DATE > 0);
        require(FUNDING_PERIOD > 0);
    }
    
    // Default function
    function ()
        payable
    {
        // Pass through to purchasing function. Will throw on failed or
        // successful ICO
        proxyPurchase(msg.sender);
    }

//
// Getters
//

    // ICO fails if aborted or minimum funds are not raised by the end date
    function fundFailed() public constant returns (bool)
    {
        return !__abortFuse
            || (now > END_DATE && etherRaised < MIN_ETH_FUND);
    }
    
    // Funding succeeds if not aborted, minimum funds are raised before end date
    function fundSucceeded() public constant returns (bool)
    {
        return !fundFailed()
            && etherRaised >= MIN_ETH_FUND;
    }

    // Returns the number of tokens for given amount of ether for an address 
    function ethToTokens(uint _wei) public constant returns (uint)
    {
        return _wei.mul(TOKENS_PER_ETH);
    }
    
    // Returns calculated NRG tokens for given USD rate
    function balanceOfNRG(address _addr, uint _centsPerEth)
        public
        constant
        returns (uint nrg_)
    {
        nrg_ = balances[_addr] * _centsPerEth / CENTS_PER_NRG;
    }

//
// ICO functions
//

    // The fundraising can be aborted any time before funds are swept to the
    // fundWallet.
    // This will force a fail state and allow refunds to be collected.
    function abort()
        public
        noReentry
        onlyOwner
        returns (bool)
    {
        require(!icoSuccessful);
        delete __abortFuse;
        return true;
    }
    
    // General addresses can purchase tokens during funding
    function proxyPurchase(address _addr)
        payable
        noReentry
        returns (bool)
    {
        require(!fundFailed());
        require(!icoSuccessful);
        require(now <= END_DATE);
        require(msg.value > 0);
        
        // Get ether to token conversion
        uint tokens = ethToTokens(msg.value);
        
        // transfer tokens from fund wallet
        balances[_addr] = balances[_addr].add(tokens);
        totalSupply = totalSupply.add(tokens);
        Transfer(0x0, _addr, tokens);

        // Update holder payments
        etherContributed[_addr] = etherContributed[_addr].add(msg.value);
        
        // Update funds raised
        etherRaised = etherRaised.add(msg.value);
        
        // Bail if this pushes the fund over the USD cap or Token cap
        require(etherRaised <= MAX_ETH_FUND);

        return true;
    }
    
    // Owner can sweep a successful funding to the fundWallet
    // Contract can be aborted up until this action.
    function finaliseICO()
        public
        onlyOwner
        preventReentry()
        returns (bool)
    {
        require(fundSucceeded());

        icoSuccessful = true;

        FundsTransferred(devWallet, this.balance / 100);
        devWallet.transfer(this.balance / 100);
        
        FundsTransferred(fundWallet, this.balance);
        fundWallet.transfer(this.balance);
        return true;
    }
    
    // Refunds can be claimed from a failed ICO
    function refund(address _addr)
        public
        preventReentry()
        returns (bool)
    {
        require(fundFailed());
        
        uint value = etherContributed[_addr];

        // Transfer tokens back to origin
        // (Not really necessary but looking for graceful exit)
        xfer(_addr, fundWallet, balances[_addr]);

        // garbage collect
        delete etherContributed[_addr];

        Refunded(_addr, value);
        if (value > 0) {
            _addr.transfer(value);
        }
        return true;
    }
    
    // Migrates all tokens from an address to NRG contract tokens
    function migrate(address _addr)
        public
        returns (bool)
    {
        return transfer(nrgAddr, balances[_addr]);
    }

//
// ERC20 overloaded functions
//

    function xfer(address _from, address _to, uint _amount)
        internal
        preventReentry
        returns (bool)
    {
        // ICO must be successful
        require(icoSuccessful);
        require(_amount <= balances[_from]);

        Transfer(_from, _to, _amount);
        
        // avoid wasting gas on 0 token transfers
        if(_amount == 0) return true;
        
        balances[_from] = balances[_from].sub(_amount);
        balances[_to]   = balances[_to].add(_amount);

        if (mustMigrate)
        {
            // intercontract token sender transfer. Any non-zero amount will
            // migrate entire balance
            require(_to == nrgAddr);
            require(ERC20Token(nrgAddr).transfer(_from, balances[_from]));
            MigratedTo(_from, nrgAddr, _amount);
        }        
        return true;
    }
    
    function approve(address _spender, uint _amount)
        public
        noReentry
        returns (bool)
    {
        // ICO must be successful
        require(icoSuccessful);
        super.approve(_spender, _amount);
        return true;
    }

//
// Contract managment functions
//

    // To initiate an ownership change
    function changeOwner(address _newOwner)
        public
        noReentry
        onlyOwner
        returns (bool)
    {
        ChangeOwnerTo(_newOwner);
        newOwner = _newOwner;
        return true;
    }

    // To accept ownership. Required to prove new address can call the contract.
    function acceptOwnership()
        public
        noReentry
        returns (bool)
    {
        require(msg.sender == newOwner);
        ChangedOwner(owner, newOwner);
        owner = newOwner;
        return true;
    }

    // Change the address of the Veredictum contract address. The contract
    // must impliment the `Notify` interface.
    function setNRG(address _kAddr)
        public
        noReentry
        onlyOwner
        returns (bool)
    {
        nrgAddr = _kAddr;
        return true;
    }
    
    // NRG contract opens migration when it's ICO is finalized.
    // If NRG ICO fails, ZCS tokens remain indefinately transferrable
    // speculation zombies.
    function setMigrate()
        public
        noReentry
        returns (bool)
    {
        require(msg.sender == nrgAddr);
        mustMigrate = true;
        return true;
    }
    
    // The contract can be selfdestructed after abort and ether balance is 0.
    function destroy()
        public
        noReentry
        onlyOwner
    {
        require(!__abortFuse);
        require(this.balance == 0);
        selfdestruct(owner);
    }
    
    // Owner can salvage ERC20 tokens that may have been sent to the account
    function transferAnyERC20Token(address _kAddr, uint _amount)
        public
        onlyOwner
        preventReentry
        returns (bool) 
    {
        require(ERC20Token(_kAddr).transfer(owner, _amount));
        return true;
    }
}


// To test intercontract ZCS to NRG token migration/conversion
contract NRGTestRig is ERC20Token
{
//
// Events
//

    event MigratedFrom(
        address indexed _from,
        address indexed _to,
        uint indexed _amount,
        uint rate,
        uint nrg);
    
    // USD per NRG in cents during ICO
    uint public constant ICO_CENTS_PER_NRG = 150;
    
    // TODO: Use oracle to get rate for production contract
    uint public rate = 30000;

    // TODO: Needs to be hard coded parameter in production contract
    address public zcsAddr;
    
    // TODO: Remove in production contract 
    function setZCSAddr(address _kAddr) { zcsAddr = _kAddr; }

    // Opens migration of tokens to NRG contract tokens
    function finalizeICO() public returns (bool)
    {
        return ZeroCarbonSeedAbstract(zcsAddr).setMigrate();
    }
    
//
// ERC20 overloaded functions
//

    function xfer(address _from, address _to, uint _amount)
        internal
        returns (bool)
    {
        // avoid wasting gas on 0 token transfers
        if(_amount == 0) return true;
        
        if (msg.sender == zcsAddr) {
            // Intercontract token reciever mints NRG from ZCS
            require(rate != 0);
            uint nrg = _amount * rate / ICO_CENTS_PER_NRG;
            balances[_to] = balances[_to].add(nrg);
            totalSupply = totalSupply.add(nrg);            
            MigratedFrom(zcsAddr, _to, _amount, rate, nrg);
            Transfer(zcsAddr, _to, nrg);
        } else {
            // Normal transfer
            require(_amount <= balances[_from]);
            balances[_from] = balances[_from].sub(_amount);
            balances[_to]   = balances[_to].add(_amount);
        }
        
        Transfer(_from, _to, _amount);
        return true;
    }
}