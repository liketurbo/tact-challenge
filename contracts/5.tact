import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap 
  The smart contract contains a bunch of different NFTs.
  A user brings his NFT (sends it to the smart contract), with 2.1 TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smart contract randomly chooses some NFT from the available NFTs (including the newly incoming one) and gives it to the user in exchange for the brought NFT (but occasionally just returns user's NFT in some cases).
  Admin can deposit NFTs without swap logic. Any NFT received from the admin is considered deposited. Admin can't swap.
  Admin can withdraw all NFTs at once, and also all TONs collected from users as fees.
  Implement getter that will return NFT addresses held by the smart contract.
  Implement getter that will return the amount of admin`s profit collected.

  In details, the smart contract (later: SC) should have this logic:
  Messages
  * AdminWithdrawalProfit 
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
  * AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin 
   - SC should be able to withdraw all NFTs by a single message from admin
  * OwnershipAssigned 
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
     but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
  
  Getters
  * profit
   - returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
  * nfts
   - returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values 
     the order of NFTs in this dictionary doesn't matter
*/

message AdminWithdrawalProfit {
  queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
  queryId: Int as uint64;
}

message AdminFetchProfit {
  queryId: Int as uint64;
}

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

contract Task5 with Deployable {
  seed: Int as uint128;
  owner: Address;
  nftsArr: map<Int as uint16, Address>;
  nftsLen: Int as uint16;

  const MinTonForStorage: Int = ton("0.1"); // enough for 1 KB of storage for 25 years
  const GasConsumption: Int = ton("0.1");
  const Commission: Int = ton("2");
  
  init(seed: Int, owner: Address) {
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
    self.owner = owner;
    self.nftsArr = emptyMap();
    self.nftsLen = 0;
  }

  receive(msg: OwnershipAssigned) {
    if (msg.prevOwner == self.owner) { // from admin
      self.nftsPush(sender());
    } else {
      if (context().value >= self.Commission + self.GasConsumption) { // enough gas
        self.nftsPush(sender());
        let i: Int = random(0, self.nftsLen - 1);
        let nft: Address = self.nftsRetain(i);
        nativeReserve(myBalance() - context().value + self.Commission, 0);
        send(SendParameters{
          to: nft,
          value: 0,
          mode: SendRemainingBalance,
          body: Transfer { 
            queryId: msg.queryId,           
            newOwner: msg.prevOwner, 
            responseDestination: msg.prevOwner, 
            customPayload: null, 
            forwardAmount: 0, 
            forwardPayload: emptySlice() 
          }.toCell()
        });
      } else if (context().value >= self.GasConsumption) {
        send(SendParameters{
          to: sender(),
          value: ton("0.02"),
          mode: 0,
          body: Transfer { 
            queryId: msg.queryId,           
            newOwner: msg.prevOwner, 
            responseDestination: msg.prevOwner, 
            customPayload: null, 
            forwardAmount: 0, 
            forwardPayload: emptySlice() 
          }.toCell()
        });
      }
    }
  }

  receive(msg: AdminWithdrawalProfit) {
    require(sender() == self.owner, "Insufficient privileges");
    nativeReserve(self.MinTonForStorage, 0);
    send(SendParameters{
        to: sender(),
        value: 0, 
        mode: SendRemainingBalance,
        body: AdminFetchProfit {
          queryId: msg.queryId
        }.toCell()
    });
  }

  receive(msg: AdminWithdrawalAllNFTs) {
    if (sender() == self.owner) {
      require(context().value >= ton("1") + self.nftsLen * ton("0.08"), "Insufficent funds");
    }
    require(sender() == self.owner || sender() == myAddress(), "Invalid sender");
    let i: Int = self.nftsLen;
    let till: Int = 0;
    if (self.nftsLen >= 50) {
      till = self.nftsLen - 50;
    }
    while (i > till) {
      send(SendParameters{
        to: self.nftsArr.get(i - 1)!!,
        value: ton("0.02"),
        mode: 0,
        body: Transfer { 
          queryId: msg.queryId,
          newOwner: self.owner, 
          responseDestination: self.owner, 
          customPayload: null, 
          forwardAmount: 0, 
          forwardPayload: emptySlice() 
        }.toCell()
      });
      i = i - 1;
      self.nftsPop();
    }
    if (i > 0) {
      send(SendParameters{
        to: myAddress(),
        value: 0,
        mode: SendRemainingValue,
        body: AdminWithdrawalAllNFTs{
          queryId: msg.queryId
        }.toCell()
      });
    }
  }

  get fun profit(): Int { 
    return max(0, myBalance() - self.MinTonForStorage);
  }
  
  get fun nfts(): map<Int as uint16, Address> { 
    return self.nftsArr;
  }

  fun nftsPush(nft: Address) {
    self.nftsArr.set(self.nftsLen, nft);
    self.nftsLen = self.nftsLen + 1;
  }

  fun nftsClear() {
    self.nftsArr = emptyMap();
    self.nftsLen = 0;
  }

  fun nftsPop() {
    require(self.nftsLen > 0, "Array is empty");
    self.nftsArr.set(self.nftsLen - 1, null);
    self.nftsLen = self.nftsLen - 1;
  }

  fun nftsRetain(i: Int): Address {
    require(self.nftsLen > 0, "Array is empty");
    let nft: Address = self.nftsArr.get(i)!!;
    let last: Address = self.nftsArr.get(self.nftsLen - 1)!!;
    self.nftsArr.set(i, last);
    self.nftsArr.set(self.nftsLen - 1, null);
    self.nftsLen = self.nftsLen - 1;
    return nft;
  }
}