/*
file:   ZeroCarbonSeed.sol
ver:    0.2.2
author: Darryl Morris
date:   23-Sep-2017
email:  o0ragman0o AT gmail.com
(c) Darryl Morris 2017

A collated contract set for a token prefund specific to the requirments of
Beond's ZeroCarbon green energy subsidy token.

This presale token (ZCS) pegs minted tokens against USD at a rate of
2000ZCS/$1  ($0.0005/NRG) where the ETH/USD echange rate is static and set at
the time of deployment.

The owner can finalize the ICO any time after the minimum funding cap has been
reached.

The owner can abort the contract any time before a successful call to
`finalizeICO()`

Upon a successful NRG token ICO, ZCS tokens will be transferable to NRG tokens
at a 1:1 rate by the holder calling `transfer(<NRG contract address>,<amount>)`

No premint, postmint, bonus or reserve tokens will be awarded and all tokens are
created by direct funding during the ICO funding phase.

Tokens become transferrable upon a successful call by the owner to
`finalizeICO()`.
ZCS tokens remain transferrable indefinitly until transferred to the NRG
contract address whereupon the owner recieves NRG tokens of the same amount in
the NRG contract.

Investors can claim a full refund if the ICO fails to raise minimum funds by the
end date or if the owner calls `abort()`

The trust/risk relationship between investors and the owner of a successful ZCS
ICO is that the owner must provide a viable NRG production contract address in
the future.

This contract guarantees that ZCS tokens will transfer to NRG tokens only on the
condition that the NRG contract is viable and its ICO successful.

Migration process
-----------------
1. ZCS ICO succeeds
2. NRG contract is deployed with `zcsContract` as precompiled constant;
   Constructor sets balanceOf(<zcsContract>) = zcsContract.totalSupply();
3. ZCSToken.setNrgContract(<nrgContract>) is call by owner.
4. Audit that ZCSToken.nrgContract() is equal to actual NRGToken address
5. NRGToken.finalizeICO() is called by owner after fundSucceeded == true
5.1 NRGToken.finalizeICO() calls ZCSToken.setMigrate()
6. Holders call ZCSToken.transfer(<nrgContract>, <amount>)
6.1 ZCSToken.transfer() calls NRGToken.transfer(<holderAddr>, <amount>)
8. Holders check NRGToken.balanceOf(<holderAddr>) to confirm migration


Timeline
--------
+-+- ZCS Opens November 2017. 2000 ZCS tokens / USD
|
|
|
+-+- Close <=21 days after open || $250,000 <= minted <= $500,000
| +- 1% of funds transferred to commision wallet
| +- 99% Funds transferred to round ZCS fund wallet
|
... NRG ICO TBD


Release Notes
-------------
0.2.2

* fixed edge case DOS posibility where attacker could block `destroy()` by
selfdestructing funds to the contract. Now tests against `refunded==etherRaised`
rather than `balance.this==0`
* Redeclared `refund(address _addr)` to `refund()`
* Declared `refundFor(address _addr)`
* Removed overloaded near identical Transfer/TransferFrom (which had a critical
scoping failure introduced in 0.2.1)
* Overloaded `xfer()` instead with migration logic.
* removed `nrgConfirmed` (using `canMigrate` flag instead)

License
-------
This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See MIT Licence for further details.
<https://opensource.org/licenses/MIT>.

*/


pragma solidity 0.4.13;

/*-----------------------------------------------------------------------------\

Zero Carbon Seed token sale configuration

\*----------------------------------------------------------------------------*/

// Contains token sale parameters
contract ZCSTokenConfig
{
    // ERC20 trade name and symbol
    string public           name            = "Zero Carbon Seed";
    string public           symbol          = "ZCS";

    // Owner has power to abort, discount addresses, sweep successful funds,
    // change owner, sweep alien tokens, set NRG contract address
    address public          owner           = msg.sender;
    
    // Fund wallet should also be audited prior to deployment
    // NOTE: Must be checksummed address!
    address public          fundWallet      = msg.sender;
    // ICO developer commision wallet (1% of funds raised)
    address public          devWallet       = msg.sender; // 0x0;
    
    // Developer commision divisor (1% of funds raised);
    uint public constant    COMMISION_DIV   = 100;

    // ZCS per $1 USD at $0.0005/ZCS
    uint public constant    ZCS_PER_USD     = 2000;
    
    // USD/ETH Exchange Rate
    uint public constant    USD_PER_ETH     = 200; // $200
    
    // USD min and max caps
    uint public constant    MIN_USD_FUND    = 250000; // $250,000
    uint public constant    MAX_USD_FUND    = 500000; // $500,000

    // Funding begins on 14th August 2017
    // `+ new Date('14 August 2017 GMT+0')/1000`
    // uint public constant    START_DATE      = 1502668800;
    uint public START_DATE                  = now;

    // Period for fundraising
    uint public constant    FUNDING_PERIOD  = 21 days;
    
    // TODO: Add premint addresses and balances
}


library SafeMath
{
    // a add to b
    function add(uint a, uint b) internal constant returns (uint c) {
        c = a + b;
        assert(c >= a);
    }
    
    // a subtract b
    function sub(uint a, uint b) internal constant returns (uint c) {
        c = a - b;
        assert(c <= a);
    }
    
    // a multiplied by b
    function mul(uint a, uint b) internal constant returns (uint c) {
        c = a * b;
        assert(a == 0 || c / a == b);
    }
    
    // a divided by b
    function div(uint a, uint b) internal constant returns (uint c) {
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
|()                      |T          |T         |F           |T            |F          |
|abort()                 |T          |T         |T           |T            |F          |
|proxyPurchase()         |T          |T         |F           |T            |F          |
|finaliseICO()           |F          |F         |F           |T            |T          |
|refund()                |F          |F         |T           |F            |F          |
|refundFor()             |F          |F         |T           |F            |F          |
|transfer()              |F          |F         |F           |F            |T          |
|transferFrom()          |F          |F         |F           |F            |T          |
|approve()               |F          |F         |F           |F            |T          |
|changeOwner()           |T          |T         |T           |T            |T          |
|acceptOwnership()       |T          |T         |T           |T            |T          |
|setNrgContract()        |T          |T         |T           |T            |T          |
|setMigrate()            |F          |F         |F           |F            |!canMigrate|
|destroy()               |F          |F         |!__abortFuse|F            |F          |
|transferExternalTokens()|T          |T         |T           |T            |T          |

\*----------------------------------------------------------------------------*/

contract ZCSTokenAbstract
{
    // Logged upon refund
    event Refunded(address indexed _addr, uint _value);
    
    // Logged when new owner accepts ownership
    event ChangedOwner(address indexed _from, address indexed _to);
    
    // Logged when owner initiates a change of ownership
    event ChangeOwnerTo(address indexed _to);
    
    // Logged when ICO ether funds are transferred to an address
    event FundsTransferred(address indexed _wallet, uint indexed _value);

    // This fuse blows upon calling abort() which forces a fail state
    bool public __abortFuse = true;
    
    // Set to true after the fund is swept to the fund wallet, allows token
    // transfers and prevents abort()
    bool public icoSucceeded;
    
    // Is set to open migration of ZCS tokens to the NRG contract
    bool public canMigrate;

    // Token conversion factors are calculated with decimal places at parity with ether
    uint8 public constant decimals = 18;

    // An address authorised to take ownership
    address public newOwner;
    
    // The Veredictum smart contract address
    address public nrgContract;
    
    // Total ether raised during funding
    uint public etherRaised;
    
    // Total ether refunded.
    uint public refunded;
    
    // Record of ether paid per address
    mapping (address => uint) public etherContributed;

    // Return `true` if MIN_FUNDS were raised
    function fundSucceeded() public constant returns (bool);
    
    // Return `true` if MIN_FUNDS were not raised before END_DATE
    function fundFailed() public constant returns (bool);

    // Returns USD raised for set ETH/USD rate
    function usdRaised() public constant returns (uint);

    // Returns an amount in eth equivilent to USD at the set rate
    function usdToEth(uint) public constant returns(uint);
    
    // Returns the USD value of ether at the set USD/ETH rate
    function ethToUsd(uint _wei) public constant returns (uint);

    // Returns token/ether conversion given ether value and address. 
    function ethToTokens(uint _eth)
        public constant returns (uint);

    // Processes a token purchase for a given address
    function proxyPurchase(address _addr) payable returns (bool);

    // Owner can move funds of successful fund to fundWallet 
    function finaliseICO() public returns (bool);
    
    // Refund caller on failed or aborted sale 
    function refund() public returns (bool);

    // Refund a specified address on failed or aborted sale 
    function refundFor(address _addr) public returns (bool);

    // To cancel token sale prior to START_DATE
    function abort() public returns (bool);
    
    // Change the NRG production contract address
    function setNrgContract(address _addr) public returns (bool);
    
    // Called by NRG contract upon finalizeICO()
    function setMigrate() public returns (bool);
    
    // For owner to salvage tokens sent to contract
    function transferExternalTokens(
        address _kAddress, address _to, uint _amount)
        returns (bool);
}


/*-----------------------------------------------------------------------------\

 Zero Carbon Seed token implimentation

\*----------------------------------------------------------------------------*/

contract ZCSToken is 
    ReentryProtected,
    ERC20Token,
    ZCSTokenAbstract,
    ZCSTokenConfig
{
    using SafeMath for uint;

//
// Constants
//

    uint public constant TOKENS_PER_ETH = ZCS_PER_USD * USD_PER_ETH;
    uint public constant MIN_ETH_FUND   = 1 ether * MIN_USD_FUND / USD_PER_ETH;
    uint public constant MAX_ETH_FUND   = 1 ether * MAX_USD_FUND / USD_PER_ETH;

    // Not using constant to avoid potential 'not compile time constant'
    // timestamp bugs
    uint public END_DATE  = START_DATE + FUNDING_PERIOD;

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
    function ZCSToken()
    {
        // ICO parameters are set in VentanaTSConfig
        // Invalid configuration catching here
        require(bytes(symbol).length > 0);
        require(bytes(name).length > 0);
        require(owner != 0x0);
        require(fundWallet != 0x0);
        require(devWallet != 0x0);
        require(ZCS_PER_USD > 0);
        require(USD_PER_ETH > 0);
        require(MIN_USD_FUND > 0);
        require(MAX_USD_FUND > MIN_USD_FUND);
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

    // Returns the USD value of ether at the set USD/ETH rate
    function ethToUsd(uint _wei) public constant returns (uint)
    {
        return USD_PER_ETH.mul(_wei).div(1 ether);
    }
    
    // Returns the ether value of USD at the set USD/ETH rate
    function usdToEth(uint _usd) public constant returns (uint)
    {
        return _usd.mul(1 ether).div(USD_PER_ETH);
    }
    
    // Returns the USD value of ether raised at the set USD/ETH rate
    function usdRaised() public constant returns (uint)
    {
        return ethToUsd(etherRaised);
    }
    
    // Returns the number of tokens for given amount of ether for an address 
    function ethToTokens(uint _wei) public constant returns (uint)
    {
        return _wei.mul(TOKENS_PER_ETH);
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
        require(!icoSucceeded);
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
        require(!icoSucceeded);
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
    // Effective once but can be called multiple time to withdraw edge case
    // funds recieved by contract which can selfdestruct to this address
    function finaliseICO()
        public
        onlyOwner
        preventReentry()
        returns (bool)
    {
        require(fundSucceeded());

        icoSucceeded = true;

        // Send commision to developer wallet
        FundsTransferred(devWallet, this.balance / COMMISION_DIV);
        devWallet.transfer(this.balance / COMMISION_DIV);
        
        // Send remaining funds to fundWallet
        FundsTransferred(fundWallet, this.balance);
        fundWallet.transfer(this.balance);
        
        return true;
    }
    
    // Refunds can be claimed from a failed ICO
    function refund()
        public
        noReentry
        returns (bool)
    {
        return refundFor(msg.sender);
    }
    
    // To refund a specified address from a failed ICO
    function refundFor(address _addr)
        public
        preventReentry()
        returns (bool)
    {
        require(fundFailed());
        
        uint value = etherContributed[_addr];

        // Transfer tokens back to origin
        // (Not really necessary but looking for graceful exit)
        totalSupply = totalSupply.sub(balances[_addr]);
        xfer(_addr, 0x0, balances[_addr]);

        // garbage collect
        delete etherContributed[_addr];

        Refunded(_addr, value);
        if (value > 0) {
            refunded = refunded.add(value);
            _addr.transfer(value);
        }
        return true;
    }

//
// ERC20 overloaded functions
//

    // Process a transfer internally.
    function xfer(address _from, address _to, uint _amount)
        internal
        returns (bool)
    {
        require(icoSucceeded);
        super.xfer(_from, _to, _amount);

        if (_to == nrgContract) {
            require(canMigrate);
            require(ERC20Token(nrgContract).transfer(_from, _amount));
        }
        return true;
    }

    function approve(address _spender, uint _amount)
        public
        noReentry
        returns (bool)
    {
        // ICO must be successful
        require(icoSucceeded);
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

    // Set the address of the NRG contract.
    // Cannot be changed after canMigrate has been set to true.
    function setNrgContract(address _kAddr)
        public
        noReentry
        onlyOwner
        returns (bool)
    {
        require(!canMigrate);
        nrgContract = _kAddr;
        return true;
    }

    // NRG contract opens migration when its ICO is finalized.
    // If NRG ICO fails, setNrgContract() can be changed for a future funding
    // attempts
    function setMigrate()
        public
        noReentry
        returns (bool)
    {
        require(msg.sender == nrgContract);
        require(icoSucceeded);
        
        canMigrate = true;
        return true;
    }
    
    // The contract can be selfdestructed after abort and ether balance is 0.
    function destroy()
        public
        noReentry
        onlyOwner
    {
        require(!__abortFuse);
        require(refunded == etherRaised);
        selfdestruct(owner);
    }
    
    // Owner can salvage ERC20 tokens that may have been sent to the account
    function transferExternalTokens(address _kAddr, address _to, uint _amount)
        public
        onlyOwner
        preventReentry
        returns (bool) 
    {
        // cannot transfer NRG tokens
        require(_kAddr != nrgContract);
        require(ERC20Token(_kAddr).transfer(_to, _amount));
        return true;
    }
}


// To test intercontract ZCS to NRG token migration/conversion
contract NRGTestRig is ERC20Token
{
    bool public icoSucceeded;
    uint public constant decimals = 18;
    
    uint public totalSupply = 5000000000 * 10**decimals;

    // NRG Per USD
    uint public constant NRG_PER_USD = 667;
    
    // TODO: Needs to be hard coded parameter in production contract
    address public zcsContract;

//
// Events
//

    event MigratedFrom(
        address indexed _from,
        address indexed _to,
        uint indexed _amount);
    
    // TODO: zcsAddr needs to be hard coded parameter
    function NRGTestRig(address _zcsContract)
    {
        zcsContract = _zcsContract;
        // Cannot deploy until ZCS ICO has succeeded
        require(ZCSToken(zcsContract).icoSucceeded());

        // Load up the ZCS address with NRG balance = ZCSToken.totalSupply()
        uint zcsSupply = ZCSToken(zcsContract).totalSupply();
        balances[zcsContract] = zcsSupply;
        Transfer(0x0, this, totalSupply);

        balances[this] = totalSupply - zcsSupply;
        Transfer(0x0, this, totalSupply - zcsSupply);
    }

    // Opens migration of tokens to NRG contract tokens
    function finalizeICO() public returns (bool)
    {
        require(!icoSucceeded);
        icoSucceeded = true;
        // ZCSToken.setNRG(<NRG address>) must first be called in ZCScontract
        // else NRG cannot be finalized
        require(ZCSToken(zcsContract).setMigrate());
        return true;
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
        
        if (msg.sender == zcsContract)
            MigratedFrom(zcsContract, _to, _amount);
        // Normal transfer
        require(_amount <= balances[_from]);
        balances[_from] = balances[_from].sub(_amount);
        balances[_to]   = balances[_to].add(_amount);

        Transfer(_from, _to, _amount);
        return true;
    }
}