# Zero Carbon Seed
ICO for Beond Zero Carbon Seed (ZCS) token.

This presale token (ZCS) pegs minted tokens against USD at a rate of
2000ZCS/$1  ($0.0005/NRG) where the ETH/USD echange rate is static and set at
the time of deployment.

The owner can finalize the ICO any time after the minimum funding cap has been
reached.

The owner can abort the contract any time before a successful call to
`finalizeICO()`

Upon a successful NRG token ICO, ZCS tokens will be transferable to NRG tokens
at a 1:1 rate by the holder calling `transfer(<NRG contract address>,<amount>)`

Beond will be preminted 6,500,000,000 ZCS tokens which will seed the NRG
ecosystem.  All other tokens are created by direct funding during the ICO
funding phase.

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

## Migration process

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


## Timeline
```
+--- ZCS Opens November 2017. 2000 ZCS/USD
|
|
|
+-+- Close <=21 days after open || $250,000 <= minted <= $500,000
| +- 1% of funds transferred to commision wallet
| +- 99% Funds transferred to round ZCS fund wallet
|
... NRG ICO TBD
```

## Release Notes
0.2.4

* Added post funding KYC limit and managment
* Added developer wallet address
* To be used for audit training by Bokky's group

## License
This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See MIT Licence for further details.
<https://opensource.org/licenses/MIT>.