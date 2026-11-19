// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title DashboardPrivacyConsentManager
/// @notice Stores revocable commitments for optional aggregate-dashboard participation.
/// @dev This contract is an integrity ledger, not a personal-data store. Public-chain
///      metadata can be observable, so callers must never submit raw consent records,
///      user profiles, sensitive attributes, or reversible identifiers as hashes.
contract DashboardPrivacyConsentManager {
    error EmptyConsentHash();
    error EmptyPolicyVersionHash();
    error ConsentAlreadyActive();
    error ConsentNotActive();
    error Unauthorized();

    struct ConsentRecord {
        bytes32 consentHash;
        bytes32 policyVersionHash;
        uint64 recordedAt;
        uint64 revokedAt;
        bool active;
    }

    mapping(address => ConsentRecord) private consentRecords;

    address public immutable administrator;

    event ConsentRecorded(
        address indexed user,
        bytes32 indexed consentHash,
        bytes32 indexed policyVersionHash,
        uint64 recordedAt
    );

    event ConsentRevoked(
        address indexed user,
        bytes32 indexed priorConsentHash,
        bytes32 indexed policyVersionHash,
        uint64 revokedAt
    );

    event AdministratorTransferred(
        address indexed previousAdministrator,
        address indexed newAdministrator
    );

    modifier onlyAdministrator() {
        if (msg.sender != administrator) {
            revert Unauthorized();
        }
        _;
    }

    constructor(address initialAdministrator) {
        if (initialAdministrator == address(0)) {
            revert Unauthorized();
        }

        administrator = initialAdministrator;
    }

    /// @notice Records an active consent commitment for the caller.
    /// @param consentHash A salted, purpose-specific commitment hash generated off-chain.
    /// @param policyVersionHash A hash of the human-readable policy version accepted by the user.
    function recordConsent(
        bytes32 consentHash,
        bytes32 policyVersionHash
    ) external {
        _recordConsent(msg.sender, consentHash, policyVersionHash);
    }

    /// @notice Records an active consent commitment for a user.
    /// @dev The administrator route supports an explicitly authorized relayer only.
    ///      A production deployment should replace this route with an EIP-712 signature
    ///      verification flow before accepting third-party submissions.
    function recordConsent(
        address user,
        bytes32 consentHash,
        bytes32 policyVersionHash
    ) external onlyAdministrator {
        if (user == address(0)) {
            revert Unauthorized();
        }

        _recordConsent(user, consentHash, policyVersionHash);
    }

    /// @notice Immediately withdraws the caller's active dashboard participation consent.
    function revokeConsent() external {
        _revokeConsent(msg.sender);
    }

    /// @notice Immediately withdraws an active consent for a user through an authorized relay.
    function revokeConsent(address user) external onlyAdministrator {
        if (user == address(0)) {
            revert Unauthorized();
        }

        _revokeConsent(user);
    }

    /// @notice Returns whether the user's consent commitment is currently active.
    function checkConsent(address user) external view returns (bool) {
        return consentRecords[user].active;
    }

    /// @notice Returns non-sensitive consent state for aggregate-inclusion verification.
    /// @dev Never use this method to make eligibility, service, identity, health, or
    ///      augmentation decisions. It answers only optional dashboard participation.
    function getConsentStatus(
        address user
    )
        external
        view
        returns (
            bool active,
            bytes32 consentHash,
            bytes32 policyVersionHash,
            uint64 recordedAt,
            uint64 revokedAt
        )
    {
        ConsentRecord memory record = consentRecords[user];

        return (
            record.active,
            record.consentHash,
            record.policyVersionHash,
            record.recordedAt,
            record.revokedAt
        );
    }

    /// @notice Prevents accidental value transfers to this consent-only registry.
    receive() external payable {
        revert Unauthorized();
    }

    fallback() external payable {
        revert Unauthorized();
    }

    function _recordConsent(
        address user,
        bytes32 consentHash,
        bytes32 policyVersionHash
    ) private {
        if (consentHash == bytes32(0)) {
            revert EmptyConsentHash();
        }

        if (policyVersionHash == bytes32(0)) {
            revert EmptyPolicyVersionHash();
        }

        ConsentRecord storage record = consentRecords[user];

        if (record.active) {
            revert ConsentAlreadyActive();
        }

        uint64 recordedAt = uint64(block.timestamp);

        record.consentHash = consentHash;
        record.policyVersionHash = policyVersionHash;
        record.recordedAt = recordedAt;
        record.revokedAt = 0;
        record.active = true;

        emit ConsentRecorded(
            user,
            consentHash,
            policyVersionHash,
            recordedAt
        );
    }

    function _revokeConsent(address user) private {
        ConsentRecord storage record = consentRecords[user];

        if (!record.active) {
            revert ConsentNotActive();
        }

        uint64 revokedAt = uint64(block.timestamp);
        bytes32 priorConsentHash = record.consentHash;
        bytes32 policyVersionHash = record.policyVersionHash;

        record.active = false;
        record.revokedAt = revokedAt;

        emit ConsentRevoked(
            user,
            priorConsentHash,
            policyVersionHash,
            revokedAt
        );
    }
}
