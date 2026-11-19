// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/CrossChainRecoveryLogger.sol";

contract CrossChainRecoveryLoggerTest is Test {
    CrossChainRecoveryLogger public logger;

    // Simulated hardware identity variables
    uint256 public constant HARDWARE_PRIVATE_KEY = 0xB057B014; // Mock internal secure element seed
    address public dataCenterId;

    // Test parameters matching tight packing specs
    uint64 public constant INITIAL_NONCE = 0;
    uint32 public constant NOMINAL_FAULT_MASK = 0x00000000;
    uint32 public constant PANIC_FAULT_MASK = 0xFFFF0002;

    function setUp() public {
        logger = new CrossChainRecoveryLogger();
        dataCenterId = vm.addr(HARDWARE_PRIVATE_KEY);
    }

    /**
     * @dev Internal helper utility to generate cryptographically signed payload digests
     * matching the EIP-712 structural verification logic in the contract.
     */
    function generateMockSignature(
        uint64 nonce,
        bytes32 thermalPacket,
        uint32 faultBitmask,
        bool hwOverride,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                block.chainid,
                address(logger),
                vm.addr(privateKey),
                nonce,
                thermalPacket,
                faultBitmask,
                hwOverride
            )
        );

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    /**
     * @notice Vector 1: Verifies that nominal telemetry data can clear the verification loop cleanly.
     */
    function test_LogRecoveryMetrics_NominalFlow() public {
        // Pack nominal parameters: Q = 1500 L/hr, Tin = 55.50C (5550), Tout = 35.20C (3520)
        bytes32 nominalPacket = bytes32(abi.encodePacked(uint64(1500), uint32(5550), uint32(3520)));

        bytes memory validSig = generateMockSignature(
            INITIAL_NONCE,
            nominalPacket,
            NOMINAL_FAULT_MASK,
            false,
            HARDWARE_PRIVATE_KEY
        );

        vm.expectEmit(true, true, false, true);
        emit CrossChainRecoveryLogger.RecoveryMetricLogged(
            dataCenterId,
            INITIAL_NONCE,
            block.timestamp,
            NOMINAL_FAULT_MASK,
            false
        );

        logger.logRecoveryMetrics(
            dataCenterId,
            INITIAL_NONCE,
            nominalPacket,
            NOMINAL_FAULT_MASK,
            false,
            validSig
        );

        assertEq(logger.datacenterNonces(dataCenterId), INITIAL_NONCE + 1);
    }

    /**
     * @notice Vector 2: Replay Attack Strain. Asserts that injecting an identical nonce triggers a rollback.
     */
    function test_Revert_LogRecoveryMetrics_ReplayAttack() public {
        bytes32 nominalPacket = bytes32(abi.encodePacked(uint64(1500), uint32(5550), uint32(3520)));
        bytes memory validSig = generateMockSignature(
            INITIAL_NONCE,
            nominalPacket,
            NOMINAL_FAULT_MASK,
            false,
            HARDWARE_PRIVATE_KEY
        );

        // Execute initial valid entry transaction
        logger.logRecoveryMetrics(
            dataCenterId,
            INITIAL_NONCE,
            nominalPacket,
            NOMINAL_FAULT_MASK,
            false,
            validSig
        );

        // Attempt replay sequence string injection with the same parameters
        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainRecoveryLogger.NonceReplayAttackDetected.selector,
                INITIAL_NONCE + 1, // Expected state progression step
                INITIAL_NONCE      // Received stale counter input
            )
        );

        logger.logRecoveryMetrics(
            dataCenterId,
            INITIAL_NONCE,
            nominalPacket,
            NOMINAL_FAULT_MASK,
            false,
            validSig
        );
    }

    /**
     * @notice Vector 3: Thermal Anomaly Handling. Asserts transaction rejection if physical laws are broken.
     */
    function test_Revert_LogRecoveryMetrics_ThermalAnomaly() public {
        // Contradictory physics data: Tin = 30.00C (3000) < Tout = 60.00C (6000) while liquid is actively pumping
        bytes32 anomalyPacket = bytes32(abi.encodePacked(uint64(2000), uint32(3000), uint32(6000)));

        bytes memory anomalySig = generateMockSignature(
            INITIAL_NONCE,
            anomalyPacket,
            NOMINAL_FAULT_MASK,
            false,
            HARDWARE_PRIVATE_KEY
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainRecoveryLogger.ThermalAnomalyDetected.selector,
                uint32(3000),
                uint32(6000)
            )
        );

        logger.logRecoveryMetrics(
            dataCenterId,
            INITIAL_NONCE,
            anomalyPacket,
            NOMINAL_FAULT_MASK,
            false,
            anomalySig
        );
    }

    /**
     * @notice Vector 4: Invalid Cryptographic Signatures. Asserts isolation boundaries hold if keys do not match.
     */
    function test_Revert_LogRecoveryMetrics_InvalidSignature() public {
        bytes32 nominalPacket = bytes32(abi.encodePacked(uint64(1500), uint32(5550), uint32(3520)));
        
        // Generate a signature using a compromised key variable seed (0xBAD)
        bytes memory invalidSig = generateMockSignature(
            INITIAL_NONCE,
            nominalPacket,
            NOMINAL_FAULT_MASK,
            false,
            0xBAD
        );

        vm.expectRevert(CrossChainRecoveryLogger.InvalidCryptographicSignature.selector);

        logger.logRecoveryMetrics(
            dataCenterId,
            INITIAL_NONCE,
            nominalPacket,
            NOMINAL_FAULT_MASK,
            false,
            invalidSig
        );
    }

    /**
     * @notice Vector 5: Fuzzing Framework Strain. Simulates unpredictable ambient noise input patterns.
     */
    function testFuzz_LogRecoveryMetrics_StressTest(
        uint64 volumetricFlowRate,
        uint32 inputTemp,
        uint32 outputTemp,
        bool hwOverride
    ) public {
        // Enforce basic logical conditions during fuzzing bounds parameters tracking
        vm.assume(inputTemp >= outputTemp || volumetricFlowRate == 0);

        bytes32 fuzzedPacket = bytes32(abi.encodePacked(volumetricFlowRate, inputTemp, outputTemp));
        bytes memory fuzzedSig = generateMockSignature(
            INITIAL_NONCE,
            fuzzedPacket,
            NOMINAL_FAULT_MASK,
            hwOverride,
            HARDWARE_PRIVATE_KEY
        );

        logger.logRecoveryMetrics(
            dataCenterId,
            INITIAL_NONCE,
            fuzzedPacket,
            NOMINAL_FAULT_MASK,
            hwOverride,
            fuzzedSig
        );

        assertEq(logger.datacenterNonces(dataCenterId), INITIAL_NONCE + 1);
    }
}
