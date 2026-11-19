// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title InsuranceRightsRegistry
 * @dev Records insurance discrimination decisions for audit and accountability
 * Implements Article XXI protections
 */
contract InsuranceRightsRegistry {
    
    // Structs
    struct PolicyEvaluation {
        bool augmentationStatus;
        bool identityVerifiability;
        bool assistiveTechnologyUse;
        bool deniesCoverage;
        bool limitsCoverage;
        bool differentialPricing;
    }
    
    struct CoverageRequest {
        string coverageDecision; // "approved", "denied", "limited"
        string augmentationStatus; // "not_applicable", "present", "history"
        bool actuarialJustification;
        string limitationScope; // "standard_limitation", "custom_limitation"
        uint256 premiumAdjustment;
        bool requiresDeactivation;
        bool requiresRemoval;
        bool emergencyJustification;
    }
    
    struct ServiceEvaluation {
        string procedureType; // "diagnostic", "surgical", "rehabilitation", "emergency_care"
        bool compatibleWithAugmentations;
        bool respectsAugmentations;
        bool addressesAugmentationRelatedNeeds;
        bool accommodatesAssistiveTechnology;
    }
    
    struct DecisionRecord {
        address provider;
        bytes32 requestId;
        bool allowed;
        uint256 violationCount;
        string[] findings;
        string[] requiredRemedies;
        uint256 timestamp;
        bool finalized;
    }
    
    // State variables
    mapping(bytes32 => DecisionRecord) public decisions;
    mapping(address => bytes32[]) public providerDecisions;
    uint256 public decisionCount;
    
    // Events
    event DecisionRecorded(
        bytes32 indexed requestId,
        address indexed provider,
        bool allowed,
        uint256 violationCount,
        uint256 timestamp
    );
    
    event ViolationDetected(
        bytes32 indexed requestId,
        string violationType,
        string detail,
        uint256 timestamp
    );
    
    // Modifiers
    modifier onlyProvider() {
        require(msg.sender != address(0), "Invalid provider");
        _;
    }
    
    // Functions
    
    /**
     * @dev Records a decision for audit purposes
     * @param requestId Unique identifier for the request
     * @param policy The policy evaluation
     * @param request The coverage request
     * @param service The service evaluation
     */
    function recordDecision(
        bytes32 requestId,
        PolicyEvaluation calldata policy,
        CoverageRequest calldata request,
        ServiceEvaluation calldata service
    ) external onlyProvider {
        require(decisions[requestId].timestamp == 0, "Request already recorded");
        
        // Validate policy (Section 21.1)
        bool hasDiscrimination = _checkDiscrimination(policy);
        
        // Validate coverage decision (Section 21.2)
        bool hasCoverageViolation = _checkCoverageDecision(request);
        
        // Validate service accessibility (Section 21.3)
        bool hasAccessibilityViolation = _checkAccessibility(service);
        
        // Validate forced changes (Section 21.4)
        bool hasForcedChangeViolation = _checkForcedChanges(request);
        
        uint256 violationCount = 0;
        string[] memory findings = new string[](4);
        uint256 findex = 0;
        
        if (hasDiscrimination) {
            findings[findex++] = "Discrimination based on augmentation status, identity verifiability, or assistive technology use";
            violationCount++;
            emit ViolationDetected(requestId, "discrimination", "Section 21.1 violation", block.timestamp);
        }
        
        if (hasCoverageViolation) {
            findings[findex++] = "Coverage denied, limited, or priced differently based on augmentation status without actuarial justification";
            violationCount++;
            emit ViolationDetected(requestId, "coverage_violation", "Section 21.2 violation", block.timestamp);
        }
        
        if (hasAccessibilityViolation) {
            findings[findex++] = "Healthcare service not accessible to augmented citizens";
            violationCount++;
            emit ViolationDetected(requestId, "accessibility_violation", "Section 21.3 violation", block.timestamp);
        }
        
        if (hasForcedChangeViolation) {
            findings[findex++] = "Requires deactivation or removal of augmentations as condition of coverage without emergency justification";
            violationCount++;
            emit ViolationDetected(requestId, "forced_change_violation", "Section 21.4 violation", block.timestamp);
        }
        
        bool allowed = violationCount == 0;
        
        DecisionRecord storage record = decisions[requestId];
        record.provider = msg.sender;
        record.requestId = requestId;
        record.allowed = allowed;
        record.violationCount = violationCount;
        record.timestamp = block.timestamp;
        record.finalized = true;
        
        // Store findings
        for (uint256 i = 0; i < findex; i++) {
            record.findings.push(findings[i]);
        }
        
        // Store remedies
        if (!allowed) {
            record.requiredRemedies.push("Remove discrimination based on augmentation status, identity verifiability, or assistive technology use");
            record.requiredRemedies.push("Provide coverage based on actuarial risk, not augmentation status");
            record.requiredRemedies.push("Ensure healthcare services are compatible with augmentations");
            record.requiredRemedies.push("Do not require deactivation or removal of augmentations as a condition of coverage");
        }
        
        providerDecisions[msg.sender].push(requestId);
        decisionCount++;
        
        emit DecisionRecorded(requestId, msg.sender, allowed, violationCount, block.timestamp);
    }
    
    /**
     * @dev Checks for discrimination (Section 21.1)
     */
    function _checkDiscrimination(PolicyEvaluation memory policy) private pure returns (bool) {
        if (policy.augmentationStatus && policy.deniesCoverage) return true;
        if (policy.identityVerifiability && policy.deniesCoverage) return true;
        if (policy.assistiveTechnologyUse && policy.deniesCoverage) return true;
        
        if (policy.augmentationStatus && policy.limitsCoverage) return true;
        if (policy.identityVerifiability && policy.limitsCoverage) return true;
        if (policy.assistiveTechnologyUse && policy.limitsCoverage) return true;
        
        if (policy.augmentationStatus && policy.differentialPricing) return true;
        if (policy.identityVerifiability && policy.differentialPricing) return true;
        if (policy.assistiveTechnologyUse && policy.differentialPricing) return true;
        
        return false;
    }
    
    /**
     * @dev Checks coverage decision (Section 21.2)
     */
    function _checkCoverageDecision(CoverageRequest memory request) private pure returns (bool) {
        if (keccak256(bytes(request.coverageDecision)) == keccak256(bytes("denied"))) {
            if (keccak256(bytes(request.augmentationStatus)) != keccak256(bytes("not_applicable"))) {
                if (!request.actuarialJustification) return true;
            }
        }
        
        if (keccak256(bytes(request.coverageDecision)) == keccak256(bytes("limited"))) {
            if (keccak256(bytes(request.augmentationStatus)) != keccak256(bytes("not_applicable"))) {
                if (keccak256(bytes(request.limitationScope)) != keccak256(bytes("standard_limitation"))) {
                    return true;
                }
            }
        }
        
        if (request.premiumAdjustment > 0) {
            if (keccak256(bytes(request.augmentationStatus)) != keccak256(bytes("not_applicable"))) {
                if (!request.actuarialJustification) return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev Checks service accessibility (Section 21.3)
     */
    function _checkAccessibility(ServiceEvaluation memory service) private pure returns (bool) {
        if (keccak256(bytes(service.procedureType)) == keccak256(bytes("diagnostic"))) {
            if (!service.compatibleWithAugmentations) return true;
        }
        
        if (keccak256(bytes(service.procedureType)) == keccak256(bytes("surgical"))) {
            if (!service.respectsAugmentations) return true;
        }
        
        if (keccak256(bytes(service.procedureType)) == keccak256(bytes("rehabilitation"))) {
            if (!service.addressesAugmentationRelatedNeeds) return true;
        }
        
        if (keccak256(bytes(service.procedureType)) == keccak256(bytes("emergency_care"))) {
            if (!service.accommodatesAssistiveTechnology) return true;
        }
        
        return false;
    }
    
    /**
     * @dev Checks forced changes (Section 21.4)
     */
    function _checkForcedChanges(CoverageRequest memory request) private pure returns (bool) {
        if (request.requiresDeactivation) {
            if (!request.emergencyJustification) return true;
        }
        
        if (request.requiresRemoval) {
            if (!request.emergencyJustification) return true;
        }
        
        return false;
    }
    
    /**
     * @dev Gets a decision record
     */
    function getDecision(bytes32 requestId) external view returns (DecisionRecord memory) {
        require(decisions[requestId].timestamp != 0, "Decision not found");
        return decisions[requestId];
    }
    
    /**
     * @dev Gets all decisions for a provider
     */
    function getProviderDecisions(address provider) external view returns (bytes32[] memory) {
        return providerDecisions[provider];
    }
    
    /**
     * @dev Gets decision count
     */
    function getDecisionCount() external view returns (uint256) {
        return decisionCount;
    }
}
