pragma solidity ^0.4.14;

// Basic signable contract
contract signableAgreement
{
    struct Party
    { // party of the agreement
        address     id;             // address of the party
        bool        signed;         // signed flag
    }
    
    Party[] public  parties;        // Array of parties. parties[0] is empty!
    bool  public    isSigned;       // flag for signing contract
    
    modifier signed()
        { require(isSigned); _; }
        
    function Sign()
    {// sign contract
        isSigned = true;
        for(uint i = 1; i < parties.length; i++)
            if(msg.sender == parties[i].id)
                parties[i].signed = true;
            else
                isSigned = isSigned && parties[i].signed;
    }
}

// Basic contract for obligations automaton
contract ObligationsContract is signableAgreement
{
    // Contract status
    enum Status { Active, Finished, Arbitration }
    
    // Obligation structure - can be deployed in separate library
    struct Obligation
    {
        uint        debtor;         // Debtors ID for obligations 
        uint        lender;         // Lender ID for obligation
        string      testSuccess;    // function name for testing obligation success
        string      testFail;       // function name for testing obligation fail
        string      testForceSuccess;// function name for testing if debtor can force success on obligation
        bool        resultSent;     // debtor notifies that he finished his obligations
        bool        isObligation;   // Test if obligation is determined
    }
    
    // Automaton state structure
    struct State
    {
        uint        activeObl;      // Obligation ID active in current state
        Status      curStatus;      // indicates that auditor is needed
        bool        isState;        // Test if state is determined
    }

    // ============== Contract data =============================
    uint public     curState;       // current state
    uint constant   initState = 1;  // Initial state
    
    State[]         states;         // State array
    Obligation[]    obligations;    // Obligations array
    
    // If obligation y fails in state x goto this state
    mapping (uint => mapping (uint => uint))  onFail;         
    // If obligation y succeds in state x goto this state
    mapping (uint => mapping (uint => uint))  onSuccess;      
    bool            callResult;     // return value for calling internal functions
    
    function ObligationsContract()
        { curState = initState; } // constructor
    function () payable 
        { throw; } // fallback
    
    // ================== Modifiers =======================
    modifier onlyDebtor()
        { require(parties[obligations[states[curState].activeObl].debtor].id == msg.sender); _; }
    modifier onlyLender()
        { require(parties[obligations[states[curState].activeObl].lender].id == msg.sender); _; }
        
    // ================ Interface =============================
    function GetStatus() constant returns (uint myStatus)
        { return uint(states[curState].curStatus); }
    function DeliverResult() signed onlyDebtor()
    {// Debtor delivers result to lender
        require(states[curState].activeObl != 0);
        obligations[states[curState].activeObl].resultSent = true;
    }
    function AcceptObligation() signed onlyLender()
    {// Lender accepts results and olbigation succeds
        uint oblID = states[curState].activeObl;
        callResult = false;
        RunFunction(obligations[oblID].testSuccess);
        require(callResult);
        
        curState = onSuccess[curState][oblID];
        require(curState != 0);
        
        ResetObligation(oblID);
    }
    function ForceAcceptObligation() signed onlyDebtor()
    {// Debtor forces accept on obligation
        uint oblID = states[curState].activeObl;
        require(obligations[oblID].resultSent);
        callResult = false;
        RunFunction(obligations[oblID].testForceSuccess);
        require(callResult);
        
        curState = onSuccess[curState][oblID];
        require(curState != 0);
        
        ResetObligation(oblID);
    }
    function ForceFailObligation() signed onlyLender()
    {// Lender forces fail on obligation
        uint oblID = states[curState].activeObl;
        callResult = false;
        RunFunction(obligations[oblID].testFail);
        require(callResult);
        
        curState = onSuccess[curState][oblID];
        require(curState != 0);
        
        ResetObligation(oblID);
    }
    
    // =================== Internal ===========================
    function AlwaysTrue() constant
        { callResult = true; }
    function AlwaysFalse()
        { callResult = false; }
    function CheckActiveObligation(uint _olbID) constant internal returns(bool isActive)
        {  return _olbID == states[curState].activeObl;  }
    function RunFunction(string funcCall) internal
        { if(this.call(bytes4(sha3(funcCall))) == false) throw; }
    function ResetObligation(uint _oblID) internal
        { obligations[_oblID].resultSent = false;  }
}

// Sample contract
contract TypeA is ObligationsContract
{
    function TypeA(address _A, address _B)
    {// constructor
        parties.length = 3;
        parties[1].id = _A;
        parties[2].id = _B;
        
        obligations.length = 4;
        obligations[1] = Obligation(1, 2, "AlwaysTrue()", "AlwaysTrue()", "AlwaysFalse()", false, true);
        obligations[2] = Obligation(2, 1, "AlwaysTrue()", "AlwaysTrue()", "AlwaysFalse()", false, true);
        obligations[3] = Obligation(2, 1, "AlwaysTrue()", "AlwaysTrue()", "AlwaysFalse()", false, true);
    
        states.length = 8;
        states[1] = State(1, Status.Active, true);
        states[2] = State(0, Status.Finished, true);
        states[3] = State(2, Status.Active, true);
        states[4] = State(3, Status.Active, true);
        states[5] = State(0, Status.Finished, true);
        states[6] = State(0, Status.Arbitration, true);
        states[7] = State(0, Status.Finished, true);
        
        onSuccess[1][1] = 3;
        onSuccess[3][2] = 5;
        onSuccess[4][3] = 7;
        
        onFail[1][1] = 2;
        onFail[3][2] = 4;
        onFail[4][3] = 6;
    }
    function () payable 
        { throw; } // fallback
    
    // ============= Implementation ===========================
    
}