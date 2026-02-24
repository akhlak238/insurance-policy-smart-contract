//SPDX-License-Identifier: No
pragma solidity ^0.8.19;

contract InsuranceStorage{
    address public immutable owner;
    address public policyContract;

    //Structure

    struct Policy{
        uint256 policyId;
        address policyHolder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 policyDuration;
        uint256 startAt;
        uint256 expiresAt;
        bool claimed;
        bool active;
    }

    struct PremiumPayment{
        address payer;
        uint256 amount;
        uint256 paidAt;
    }

    struct Claim{
        address owner;
        uint256 claimId;
        uint256 amount;
        bytes32 reason;
        bool isApproved;
        bool isReceived;
    }
    //Storage
    Policy[] internal policies;
    Claim[] internal claims;
    //insurer
    mapping(address=>bool) internal isInsurer;

    //policyHolder to policyIds
    mapping(address=>uint256[]) internal policyOf;
    //policyId to paid amount
    mapping(uint256 => uint256) internal totalPremiumPaid;
    //policyId to PremiumPayments(for history)
    mapping(uint256=>PremiumPayment[]) internal policyToPremiumPayment;

    //policyId to ClaimId(for specific policy)
    mapping(uint256=>uint256[]) internal policyClaims;
    //policyId to claimed amount
    mapping(uint256=>uint256) internal policyToClaimedAmount;

    

    constructor(){
        owner = msg.sender;
    }

    modifier onlyPolicyContract(){
        require(msg.sender == policyContract, "NotPolicyContract");
        _;
    }

    function setPolicyContract(address _policyContract) external{
        require(msg.sender == owner, "NotOwner");
        require(policyContract == address(0), "already set");
        policyContract = _policyContract;
    }

    function getPolicy(uint256 _policyId) external view returns(Policy memory){
        return policies[_policyId];
    }
    function getAllPolicies(address _policyHolder) external view returns(uint256[] memory){
        return policyOf[_policyHolder];
        // Policy[] memory userPolicies = new Policy[](_policyIds.length);
        // for(uint256 i = 0; i < _policyIds.length; i++){
        //     userPolicies[i] = policies[_policyIds[i]];
        // }
        // return userPolicies;
    }
    function getClaim(uint256 _claimId) external view returns(Claim memory){
        return claims[_claimId];
    }
    function getPolicyClaimIds(uint256 _policyId) external view returns(uint256[] memory){
        return policyClaims[_policyId];
    }

    function getPolicyIds(address _policyHolder) external view returns(uint256[] memory){
        return policyOf[_policyHolder];
    }
    function getInsurer(address _insurer) external view returns(bool){
        return isInsurer[_insurer];
    }
    function getTotalPremiumPaid(uint256 _policyId) external view returns(uint256){
        return totalPremiumPaid[_policyId];
    }
    function getPolicyToClaimedAmount(uint256 _policyId) external view returns(uint256){
        return policyToClaimedAmount[_policyId];
    }

    // setters
    function setInsurer(address _insurer) external onlyPolicyContract{
        isInsurer[_insurer] = true;
    }
    function claimApproval(uint256 _claimId) external onlyPolicyContract{
        claims[_claimId].isApproved = true;
    }
    function onClaimReceived(uint256 _claimId, uint256 _policyId) external onlyPolicyContract{
        Claim storage claim = claims[_claimId];
        Policy storage policy = policies[_policyId];
        claim.isReceived = true;
        policyToClaimedAmount[policy.policyId] += claim.amount;
        if(policyToClaimedAmount[policy.policyId] == policy.coverageAmount){
            policy.claimed = true;
            policy.active = false;
        }
    }
    function setPolicy(address _policyHolder, uint256 _premiumAmount, uint256 _coverageAmount, uint256 _policyDuration) external onlyPolicyContract{
        Policy memory policy = Policy({
            policyId: policies.length,
            policyHolder: _policyHolder,
            premiumAmount: _premiumAmount,
            coverageAmount: _coverageAmount,
            policyDuration: _policyDuration,
            startAt: block.timestamp,
            expiresAt: block.timestamp + _policyDuration * 30 days,
            claimed: false,
            active: true
        });
        policies.push(policy);
        policyOf[_policyHolder].push(policy.policyId);
    }
    function setPremium(address _payer, uint256 _amount, uint256 _policyId) external onlyPolicyContract{
        PremiumPayment memory payment = PremiumPayment({
            payer: _payer,
            amount: _amount,
            paidAt: block.timestamp
        });
        totalPremiumPaid[_policyId] += _amount;
        policyToPremiumPayment[_policyId].push(payment);
    }
    function setClaim(uint256 _policyId, address _policyHolder, uint256 _claimAmount, bytes32 _reason, bool _isApproved, bool _isReceived) external onlyPolicyContract{
        Claim memory claim = Claim({
            owner: _policyHolder,
            claimId: claims.length,
            amount: _claimAmount,
            reason: _reason,
            isApproved: _isApproved,
            isReceived: _isReceived
        });
        claims.push(claim);
        policyClaims[_policyId].push(claim.claimId);
    }

    //check that claim and policy linked
     function isPolicyLinkedToClaim(uint256 _policyId, uint256 _claimId) external view returns(bool){
        bool valid;
        for(uint256 i = 0; i < policyClaims[_policyId].length; i++){
            if(_claimId == policyClaims[_policyId][i]){
                valid = true;
                break;
            }
        }
        return valid;
    }
}

contract InsurancePolicy{

    InsuranceStorage public policyStorage;

    constructor(address _policyStorage){
        policyStorage = InsuranceStorage(_policyStorage);
    }
    receive() external payable {}

    //Events
    event PolicyIssued(address policyHolder, uint256 premiumAmount, uint256 coverageAmount, uint256 policyDuration);
    event PremiumPaid(uint256 policyId, address policyHolder, address indexed payer,  uint256 amount);
    event ClaimSubmitted(uint256 policyId, address indexed policyHolder, uint256 amount, bytes32 reason);
    event ClaimApproved(uint256 policyId, uint256 claimId, address indexed pilicyHolder, uint256 amount);
    event ClaimPaid(uint256 policyId, uint256 claimId, address indexed pilicyHolder, uint256 amount);

    //Modifier
    modifier onlyInsurer{
        require(policyStorage.getInsurer(msg.sender) || msg.sender == policyStorage.owner(), "NotInsurer");
        _;
    }

    modifier onlyOwner{
        require(msg.sender == policyStorage.owner(), "NotOwner");
        _;
    }
    modifier activePolicy(uint256 _policyId){
        InsuranceStorage.Policy memory policy = policyStorage.getPolicy(_policyId);
        require(policy.active && policy.expiresAt > block.timestamp, "PolicyInactive OR Expired");
        _;
    }
    //getters
    function userPolicyIds(address _policyHolder) public view returns(uint256[] memory policyIds){
        return policyStorage.getAllPolicies(_policyHolder);
    }
    function claimDetails(uint256 _claimId) public view returns(InsuranceStorage.Claim memory){
        return policyStorage.getClaim(_claimId);
    }
    function policyDetails(uint256 _policyId) public view returns(InsuranceStorage.Policy memory){
        return policyStorage.getPolicy(_policyId);
    }
    function policyClaimIds(uint256 _policyId, address _policyHolder) public view returns(uint256[] memory claimIds){
        InsuranceStorage.Policy memory policy = policyStorage.getPolicy(_policyId);
        require(policy.policyHolder == _policyHolder, "NotOwner");
        claimIds = policyStorage.getPolicyClaimIds(_policyId);
        // uint256[] memory claimIds = policyStorage.getPolicyClaimIds(_policyId);
        // InsuranceStorage.Claim[] memory claims = new InsuranceStorage.Claim[](claimIds.length);
        // for(uint256 i = 0; i< claimIds.length; i++){
        //     claims[i] = policyStorage.getClaim(claimIds[i]);
        // }
        // return claims;
    }

    //function which can be called by insurer
    function onboardInsurer(address insurer) onlyOwner public{
        policyStorage.setInsurer(insurer);
    }

    function issuePolicy(address _policyHolder, uint256 _premiumAmount, uint256 _coverageAmount, uint256 _policyDuration) onlyInsurer public{
        // duration is in months
        require(_policyHolder != address(0), "ZeroAddress");
        policyStorage.setPolicy(_policyHolder, _premiumAmount, _coverageAmount, _policyDuration);
        emit PolicyIssued(_policyHolder, _premiumAmount, _coverageAmount, _policyDuration);
    }

    function payPremium(uint256 _policyId) activePolicy(_policyId) payable public{
        InsuranceStorage.Policy memory policy = policyStorage.getPolicy(_policyId);
        require(msg.sender != address(0), "ZeroAddress");
        require(policy.policyHolder == msg.sender, "NotPolicyHolder");
        require(msg.value > 0, "zero value");
        require(
            policyStorage.getTotalPremiumPaid(_policyId) + msg.value <=
            policy.premiumAmount * policy.policyDuration,
            "PremiumExceeded"
        );
        policyStorage.setPremium(msg.sender, msg.value, _policyId);
        
        emit PremiumPaid(_policyId, policy.policyHolder, msg.sender, msg.value);           
    }

    //policy holder submit the claim
    function submitClaim(uint256 _policyId, uint256 claimAmount, bytes32 _reason) activePolicy(_policyId) public{
        InsuranceStorage.Policy memory policy = policyStorage.getPolicy(_policyId);
        uint256[] memory policyClaims = policyStorage.getPolicyClaimIds(_policyId);
        if (policyClaims.length > 0) {
            uint256 claimId = policyClaims[policyClaims.length - 1];
            InsuranceStorage.Claim  memory latestClaim = policyStorage.getClaim(claimId);
            require(latestClaim.isReceived, "AlreadyClaimInProcess");
        }
        require(policy.policyHolder == msg.sender, "NotPolicyHolder");
        
        require(claimAmount <= policy.coverageAmount - policyStorage.getPolicyToClaimedAmount(_policyId), "CoverageExceeded");
        require(policyStorage.getTotalPremiumPaid(_policyId) >= policy.premiumAmount * policy.policyDuration, "PremiumNotFullyPaid");

        policyStorage.setClaim(policy.policyId, policy.policyHolder, claimAmount,_reason, false, false);
        emit ClaimSubmitted(_policyId, policy.policyHolder, claimAmount, _reason);
    }

    //insurer will approve and pay the claim

    function approveClaim(uint256 _policyId, uint256 _claimId) onlyInsurer public{
        InsuranceStorage.Policy  memory policy = policyStorage.getPolicy(_policyId);
        InsuranceStorage.Claim memory claim = policyStorage.getClaim(_claimId);
        require(policyStorage.isPolicyLinkedToClaim(_policyId, _claimId), "InvalidClaim");
        require(policy.active, "PolicyInactive");
        require(!claim.isApproved, "AlreadyApproved");
        policyStorage.claimApproval(_claimId);
        emit ClaimApproved(_policyId, claim.claimId, policy.policyHolder, claim.amount);
    }

    function payClaim(uint256 _policyId, uint256 _claimId) onlyInsurer public{
        InsuranceStorage.Policy memory policy = policyStorage.getPolicy(_policyId);
        InsuranceStorage.Claim memory claim = policyStorage.getClaim(_claimId);
        require(policyStorage.isPolicyLinkedToClaim(_policyId, _claimId), "InvalidClaim");
        require(claim.isApproved, "InvalidClaim");
        require(!claim.isReceived, "AlreadyPaid");
        require(policy.active, "PolicyInactive");
        require(address(this).balance >= claim.amount, "InsufficientContractBalance");
        policyStorage.onClaimReceived(_claimId, _policyId);
        (bool success, ) = claim.owner.call{value: claim.amount}("");
        require(success, "TransferFailed");
        emit ClaimPaid(_policyId, _claimId, policy.policyHolder, claim.amount);
    }
}