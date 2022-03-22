pragma solidity  >=0.7.0 <0.8.0;
contract TaxiEnterprise{
    
   // STRUCTS
   struct Participant {
      address p_address;
      uint256 balance;
   }
   
   struct ProposedDriver {
        address payable p_address;
        uint salary;
        uint balance;
        uint approvalState; 
   }

   struct TaxiDriver {
      address payable d_address;
      uint salary;
      uint balance;
      uint fireState;
      bool isExist;
   }

   struct ProposedCar{
      uint32 CarID;
      uint price;
      uint validTime;
      uint approvalState;
   }

   uint contractBalance; // Total balance for participants
   
   // CONSTANTS
   uint fixedExpenses = 10 ether; 
   uint participationFee = 100 ether;


   address payable public carDealer;
   address public contractOwner;
   uint32 public ownedCarId;
   
   address [] public participantArray; // Participant addresses 
   mapping (address => Participant) participantMap; // Key: address value: Participant
  
   // VOTE MAPS
   mapping (address => bool) public forDriverVote;
   mapping (address => bool) public forCarVote;
   mapping (address => bool) public forRepurchaseVote;
   mapping (address => bool) public forFireVote;

   ProposedCar proposedCar;
   ProposedCar proposedRepurchaseCar;
   ProposedDriver proposedDriver;
   TaxiDriver taxiDriver;

   // TIME VARıABLES
   uint finalSalaryTime;
   uint finalDividendTime;
   uint finalCarExpensesTime;

   
   constructor (address payable aCarDealer) {
      contractOwner = msg.sender;
      carDealer = aCarDealer;
   
      contractBalance = 0;

      finalDividendTime = block.timestamp;
      finalCarExpensesTime = block.timestamp;

   }


    modifier onlyContractOwner {
        require(msg.sender == contractOwner, "Only contract owner can call this function.");
        _;
    }

    modifier onlyCarDealer {
        require(msg.sender == carDealer, "Only car dealer can call this function.");
        _;
    }
    
    modifier onlyDriver {
        require(msg.sender == taxiDriver.d_address, "Only the driver can call this function.");
        _;
    }
    
    modifier onlyParticipant {
        require(participantMap[msg.sender].p_address == msg.sender, "Only participants can call this function.");
        _;
    }


    function Join() public payable  {
         require(participantArray.length < 9, "There is no place to join");
         require(msg.value == participationFee, "The fee must be 100 ether");
         require(participantMap[msg.sender].p_address != msg.sender, "This address already participated ");

         participantMap[msg.sender] = Participant(msg.sender,0);
         participantArray.push(msg.sender);
         contractBalance += participationFee;

   }


   function CarProposeToBusiness(uint32 _carID, uint _price, uint _offerValidTime) public onlyCarDealer{
       require(ownedCarId == 0,"There is already a picked car.");
       proposedCar = ProposedCar({
            CarID: _carID,
            price: _price,
            validTime: _offerValidTime,
            approvalState: 0
        });

        for(uint i = 0; i < participantArray.length; i++){
            forCarVote[participantArray[i]] = false;
        }
   }


   function ApprovePurchaseCar() public onlyParticipant{
         require(!forCarVote[msg.sender], " Already voted by this address");
         if(proposedCar.approvalState > (participantArray.length / 2)){
            PurchaseCar();
         }
         else{
            proposedCar.approvalState++;
            forCarVote[msg.sender] = true;
         }
         
   }

   function PurchaseCar() public{
      require(block.timestamp <= proposedCar.validTime, "Offer valid time has been passed.");
      contractBalance -= proposedCar.price;
      if(!carDealer.send(proposedCar.price)){
          contractBalance += proposedCar.price;
          revert("Can not send to carDealer");
      }
      
      ownedCarId = proposedCar.CarID;
      
      for(uint i = 0; i < participantArray.length; i++){
            forCarVote[participantArray[i]] = false;
        }
   }

   function RepurchaseCarPropose(uint32 _carID, uint _price, uint _offerValidTime) public onlyCarDealer{
       require(ownedCarId == _carID, "Different car");
       proposedRepurchaseCar = ProposedCar({
            CarID: _carID,
            price: _price,
            validTime: _offerValidTime,
            approvalState: 0
        });

      for (uint i = 0; i < participantArray.length; i++) {
            forRepurchaseVote[participantArray[i]] = false;
        }

   }


   function ApproveSellProposal() public onlyParticipant{
       require(!forRepurchaseVote[msg.sender], " Already voted");
      if(proposedRepurchaseCar.approvalState > (participantArray.length / 2)){
            Repurchasecar();
         }
         else{
            proposedRepurchaseCar.approvalState++;
            forRepurchaseVote[msg.sender] = true;
         }
   }

   function Repurchasecar() public payable{
      require(block.timestamp < proposedRepurchaseCar.validTime,"Offer valid time has been passed.");
      msg.sender.transfer(proposedRepurchaseCar.price);
      contractBalance += proposedRepurchaseCar.price;
      delete ownedCarId;

      // Reset Votes
      for (uint i = 0; i < participantArray.length; i++) {
            forRepurchaseVote[participantArray[i]] = false;
        }

   }
   

   function ProposeDriver(address payable _driverAddress, uint _salary ) public onlyContractOwner{
      require(taxiDriver.d_address != _driverAddress,"There is already a picked driver.");
      proposedDriver = ProposedDriver({
            p_address: _driverAddress,
            salary: _salary,
            balance: 0,
            approvalState: 0
        });
      
       for(uint i = 0; i < participantArray.length; i++){
            forDriverVote[participantArray[i]] = false;
        }
   }

   function ApproveDriver() public onlyParticipant{
      require(!forDriverVote[msg.sender], " Already voted");
      if(proposedDriver.approvalState > (participantArray.length / 2)){
          SetDriver();
      }else{
         proposedDriver.approvalState ++;
         forDriverVote[msg.sender] = true;
      }
      
   }

   function SetDriver() public {
      taxiDriver = TaxiDriver({
         d_address: proposedDriver.p_address,
         salary : proposedDriver.salary,
         balance : proposedDriver.balance,
         fireState: 0,
         isExist : true
      });
      finalSalaryTime = block.timestamp;

      delete proposedDriver;

      // Reset Votes
      for(uint i = 0; i < participantArray.length; i++){
            forDriverVote[participantArray[i]] = false;
        }
   }

   function ProposeFireDriver() public onlyParticipant{
      require(!forFireVote[msg.sender], " Already voted");
      require(taxiDriver.isExist == true, "There is no driver");
      if(taxiDriver.fireState > (participantArray.length / 2)){
         FireDriver();
      }else{
         taxiDriver.fireState ++;
         forFireVote[msg.sender] = true;
      }
   }

   function FireDriver() public {
      contractBalance -= taxiDriver.balance;
      if(!taxiDriver.d_address.send(taxiDriver.balance)){
            contractBalance += taxiDriver.balance;
            revert("Can not send to taxiDriver");
        }
        
      delete taxiDriver;
      // Reset Votes
      for(uint i = 0; i < participantArray.length; i++){
            forFireVote[participantArray[i]] = false;
        }      

   }

   function LeaveJob() public onlyDriver{
      require(taxiDriver.isExist == true,"There is no driver");
      FireDriver();
   }

   function GetCharge() public payable{
      contractBalance += msg.value;
   }

   function GetSalary() public onlyDriver {
      require((block.timestamp - finalSalaryTime) >= 2592000);
      require(taxiDriver.isExist == true, "There is no driver");
      require(contractBalance >= taxiDriver.salary,"Not enough balance to pay taxi driver's salary");
      finalSalaryTime = block.timestamp;
      contractBalance -= taxiDriver.salary;
      taxiDriver.balance += taxiDriver.salary;

      if(taxiDriver.balance > 0){
         taxiDriver.d_address.transfer(taxiDriver.balance);
         taxiDriver.balance = 0;
      }
   }


   function CarExpenses() public onlyParticipant{
      require((block.timestamp -finalCarExpensesTime) >= 15778463);
      require(ownedCarId != 0);
      require(contractBalance >= fixedExpenses);
      contractBalance -= fixedExpenses;
      if(!carDealer.send(fixedExpenses)){
         contractBalance += fixedExpenses;
         revert("Can not send");
      }
      finalCarExpensesTime = block.timestamp;
   }

   function PayDividend() public onlyParticipant{
      require((block.timestamp -finalDividendTime) >= 15778463);
      require(contractBalance > participationFee * participantArray.length);
      
      uint dividendMoney = contractBalance / participantArray.length;
        for (uint i = 0; i < participantArray.length; i++) {
            participantMap[participantArray[i]].balance += dividendMoney;
            contractBalance -= dividendMoney;
        }
        
        finalDividendTime = block.timestamp;
   }


   function GetDividend() public payable onlyParticipant{
      if (participantMap[msg.sender].balance <= 0){
         revert("There is no ether in participant balance");
      }
      if(!msg.sender.send(participantMap[msg.sender].balance)){
            revert("Can not send");
        }
        participantMap[msg.sender].balance = 0;
   }

   
   fallback() external {
        revert ();
   }
   
   


   


}
 


