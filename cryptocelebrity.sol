pragma solidity ^0.6.0;

contract ERC721 {
    function approve(address _to, uint256 _tokenId) public;
    function balanceOf(address _owner) public view returns (uint256 balance);
    function implementsERC721() pure public returns (bool);
    function ownerOf(uint256 _tokenId) public view returns (address addr);
    function takeOwnership(uint256 _tokenId) public;
    function totalSupply() public view returns (uint256 total);
    function transferFrom(address _from, address _to, uint256 _tokenId) public;
    function transfer(address _to, uint256 _tokenId) public;
    
    event Transfer(address indexed from, address indexed to, uint256 tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 tokenId);
}

contract CelebrityToken is ERC721 {
    
    // Events
    // birth event is fired whenever a new person comes into existence
    event Birth(uint256 tokenId, string name, address owner);
    
    // token sold event is fired whenver a token is sold
    event TokenSold(uint256 tokenId, uint256 oldPrice, uint256 newPrice, address prevOwner, address winner, string name);
    
    event Transfer(address from, address to, uint256 tokenId);
    
    // Constants
    string public constant NAME = "CryptoCelebrities";
    string public constant SYMBOL = "Celebrity Token";
    
    uint256 private startingPrice = 0.001 ether;
    uint256 private constant PROMO_CREATION_LIMIT = 5000;
    uint256 private firststepLimit = 0.053613 ether;
    uint256 private secondStepLimit = 0.564957 ether;
    
    // Storage
    // mapping from person id to the address that owns them
    mapping(uint256 => address) public personIndexToOwner;
    
    // mapping from owner address to count of tokens that address owns
    mapping(address => uint256) private ownershipTokenCount;
    
    // mapping from person id to an address that has been approved to call
    mapping(uint256 => address) public personIndexToApproved;
    
    // mapping from person id to the price of the token
    mapping(uint256 => uint256) private personIndexToPrice;
    
    // Addresses of the accounts that can execute actions within roles
    address public ceoAddress;
    address public cooAddress;
    
    uint256 public promoCreatedCount;
    
    // DataTypes
    struct Person {
        string name;
    }
    
    Person[] private persons;
    
    // ACCESS MODIFIERS
    // modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress);
        _;
    }
    
    // modifier for COO-only functionality
    modifier onlyCOO() {
        require(msg.sender == cooAddress);
        _;
    }
    
    // modifier for contract owner only functionality
    modifier onlyCLevel() {
        require(msg.sender == ceoAddress || msg.sender == cooAddress);
        _;
    }
    
    // CONSTRUCTOR
    constructor() public {
        ceoAddress = msg.sender;
        cooAddress = msg.sender;
    }
    
    // PUBLIC FUNCTIONS
    // Grant another address the right to transfer token
    function approve(address _to, uint256 _tokenId) public {
        require(_owns(msg.sender, _tokenId));
        
        personIndexToApproved[_tokenId] = _to;
        
        Approval(msg.sender, _to, _tokenId);
    }
    
    // querying balance of a particular account
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return ownershipTokenCount[_owner];
    }
    
    // create a new promo person with the given name, with given price and assigns it to an address
    function createPromoPerson(address _owner, string _name, uint256 _price) public onlyCOO {
        require(promoCreatedCount < PROMO_CREATION_LIMIT);
        
        address personOwner = _owner;
        if(personOwner == address(0)) {
            personOwner = cooAddress;
        }
        if(_price <= 0) {
            _price = startingPrice;
        }
        promoCreatedCount++;
        _createPerson(_name, personOwner, _price);
    }
    
    // create a new person with the given name
    function createContractPerson(string _name) public onlyCOO {
        _createPerson(_name, _address(this), startingPrice);
    }
    
    // returns all the relevant information about a specific person
    function getPerson(uint256 _tokenId) public view returns (string personName, uint256 sellingPrice, address owner) {
        Person storage person = person[_tokenId];
        return (person.name, person.sellingPrice, person.owner);
    }
    
    function implementsERC721() public pure returns (bool) {
        return true;
    }
    
    function name() public pure returns(string) {
        return NAME;
    }
    
    function ownerOf(uint256 _tokenId) public view returns (address owner) {
        owner = personIndexToOwner[_tokenId];
        require(owner != address(0));
        return owner;
    }
    
    function payout(address _to) public onlyCLevel {
        _payout(_to);
    }
    
    // allow someone to send ether and obtain the token
    function purchase(uint256 _tokenId) public payable {
        address oldOwner = personIndexToOwner[_tokenId];
        address newOwner = msg.sender;
        
        uint256 sellingPrice = personIndexToPrice[_tokenId];
        
        // making sure token owner is not sending to self
        require(oldOwner != newOwner);
        
        // safety check to prevent against an unexpected oxo default
        require(_addressNotNull(newOwner));
        
        // making sure sent amount is not less than the sellingPrice
        require(msg.value >= sellingPrice);
        
        uint256 payment = uint256(SafeMath.div(SafeMath.mul(sellingPrice, 94), 100));
        uint256 purchaseExcess = SafeMath.sub(msg.value, sellingPrice);
        
        // update prices
        if(sellingPrice < firststepLimit) {
            // first stage 
            personIndexToPrice[_tokenId] = SafeMath.div(SafeMath.mul(sellingPrice, 200), 94);
        } else if(sellingPrice < secondStepLimit) {
            personIndexToPrice[_tokenId] = SafeMath.div(SafeMath.mul(sellingPrice, 120), 94);
        } else {
            personIndexToPrice[_tokenId] = SafeMath.div(SafeMath.mul(sellingPrice, 115), 94);
        }
        _transfer(oldOwner, newOwner, _tokenId);
        
        // pay previous token owner if owner is not contract owner
        if(oldOwner != address(this)) {
            oldOwner.transfer(payment);
        }
        
        TokenSold(_tokenId, sellingPrice, personIndexToPrice[_tokenId], oldOwner, newOwner, persons[_tokenId].name);
        
        msg.sender.transfer(purchaseExcess);
    }
    
    function priceOf(uint256 _tokenId) public view returns (uint256 price) {
        return personIndexToPrice[_tokenId];
    }
    
    // allows a new address to act as the CEO only available to current CEO
    function setCEO(address _newCEO) public onlyCEO {
        require(_newCEO != address(0));
        ceoAddress = _newCEO;
    }
    
    // assigns a new address to act as the COO only available to the current COO
    function setCOO(address _newCOO) public onlyCOO {
        require(_newCOO != address(0));
        cooAddress = _newCOO;
    } 
    
    function symbol() public pure returns (string) {
        return SYMBOL;
    }
    
    // allow pre-approved user to take ownership of a token 
    function takeOwnership(uint256 _tokenId) public {
        address newOwner = msg.sender;
        address oldOwner = personIndexToOwner[_tokenId];
        
        require(_approved(newOwner, _tokenId));
        
        _transfer(oldOwner, newOwner, _tokenId);
    }
    
    // the owner whose celebrity tokens we are intereseted in 
    // this method should never be called with smart contract code 
    function tokensOfOwner(address _owner) public view returns (uint256[] ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);
        if(tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalPersons = totalSupply();
            uint256 resultIndex = 0;
            
            uint256 personId;
            for(personId=0;personId <= totalPersons; personId++) {
                if(personIndexToOwner[personId] == _owner) {
                    result[resultIndex] = personId;
                    resultIndex++;
                }
            }
            return result;
        }
    }
    
    // for querying totalSupply of tokens
    function totalSupply() public view returns (uint256 total) {
        return persons.length;
    }
    
    // owner initiates the transfer of the token to another account
    function transfer(address _to, uint256 _tokenId) public {
        require(_owns(msg.sender, _tokenId));
        require(_addressNotNull(_to));
        
        _transfer(msg.sender, _to, _tokenId);
    }
    
    // third party initiates transfer of token from address to another address
    function transferFrom(address _from, address _to, uint256 _tokenId) public {
        require(_owns(_from, _tokenId));
        require(_approved(_to, _tokenId));
        require(_addressNotNull(_to));
        
        _transfer(_from, _to, _tokenId);
    }
    
    // PRIVATE FUNCTIONS
    function _addressNotNull(address _to) private pure returns (bool) {
        return _to != address(0);
    }
    
    // for checking approval of transfer for address _to
    function _approved(address _to, uint256 _tokenId) private view returns (bool) {
        return personIndexToApproved[_tokenId] == _to;
    }
    
    // for creating person 
    function _createPerson(string _name, address _owner, uint256 _price) private {
        Person memory _person = Person({name: _name});
        uint256 newPersonId = persons.push(_person) - 1;
        
        require(newPersonId == uint256(uint32(newPersonId)));
        
        Birth(newPersonId, _name, _owner);
        
         personIndexToPrice[newPersonId] = _price;

    // This will assign ownership, and also emit the Transfer event as
    // per ERC721 draft
    _transfer(address(0), _owner, newPersonId);
    }
    
     /// Check for token ownership
  function _owns(address claimant, uint256 _tokenId) private view returns (bool) {
    return claimant == personIndexToOwner[_tokenId];
  }

  /// For paying out balance on contract
  function _payout(address _to) private {
    if (_to == address(0)) {
      ceoAddress.transfer(this.balance);
    } else {
      _to.transfer(this.balance);
    }
  }

  /// @dev Assigns ownership of a specific Person to an address.
  function _transfer(address _from, address _to, uint256 _tokenId) private {
    // Since the number of persons is capped to 2^32 we can't overflow this
    ownershipTokenCount[_to]++;
    //transfer ownership
    personIndexToOwner[_tokenId] = _to;

    // When creating new persons _from is 0x0, but we can't account that address.
    if (_from != address(0)) {
      ownershipTokenCount[_from]--;
      // clear any previously approved ownership exchange
      delete personIndexToApproved[_tokenId];
    }

    // Emit the transfer event.
    Transfer(_from, _to, _tokenId);
  }
}



library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

