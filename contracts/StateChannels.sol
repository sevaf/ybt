pragma solidity ^0.4.2;

import "./ECVerify.sol";


contract StateChannels is ECVerify {

    uint8 constant PHASE_OPEN = 0;
    uint8 constant PHASE_CHALLENGE = 1;
    uint8 constant PHASE_CLOSED = 2;

    mapping (bytes32 => Channel) channels;

    struct Channel {
        bytes32 channelId;
        address address0;
        address address1;
        uint8 phase;
        uint challengePeriod;
        uint closingBlock;
        bytes state;
        uint sequenceNumber;
    }

    function getChannel(bytes32 channelId) returns(
        address address0,
        address address1,
        uint8 phase,
        uint challengePeriod,
        uint closingBlock,
        bytes state,
        uint sequenceNumber
    ) {
        address0 = channels[channelId].address0;
        address1 = channels[channelId].address1;
        phase = channels[channelId].phase;
        challengePeriod = channels[channelId].challengePeriod;
        closingBlock = channels[channelId].closingBlock;
        state = channels[channelId].state;
        sequenceNumber = channels[channelId].sequenceNumber;
    }

    event Error(string message);
    event LogString(string label, string message);
    event LogBytes(string label, bytes message);
    event LogBytes32(string label, bytes32 message);
    event LogNum256(uint256 num);

    function newChannel(
        bytes32 channelId,
        address address0,
        address address1,
        bytes state,
        uint256 challengePeriod,
        bytes signature0,
        bytes signature1
    ) {
        if (channels[channelId].channelId == channelId) {
            Error("channel with that channelId already exists");
            return;
        }

        bytes32 fingerprint = sha3(
            "newChannel",
            channelId,
            address0,
            address1,
            state,
            challengePeriod
        );

        if (!ecverify(fingerprint, signature0, address0)) {
            Error("signature0 invalid");
            return;
        }

        if (!ecverify(fingerprint, signature1, address1)) {
            Error("signature1 invalid");
            return;
        }

        Channel memory channel = Channel(
            channelId,
            address0,
            address1,
            PHASE_OPEN,
            challengePeriod,
            0,
            state,
            0
        );

        channels[channelId] = channel;
    }

    function updateState(
        bytes32 channelId,
        uint256 sequenceNumber,
        bytes state,
        bytes signature0,
        bytes signature1
    ) {
        tryClose(channelId);

        if (channels[channelId].phase == PHASE_CLOSED) {
            Error("channel closed");
            return;
        }

        bytes32 fingerprint = sha3(
            "updateState",
            channelId,
            sequenceNumber,
            state
        );

        if (!ecverify(fingerprint, signature0, channels[channelId].address0)) {
            Error("signature0 invalid");
            return;
        }

        if (!ecverify(fingerprint, signature1, channels[channelId].address1)) {
            Error("signature1 invalid");
            return;
        }

        if (sequenceNumber <= channels[channelId].sequenceNumber) {
            Error("sequence number too low");
            return;
        }

        channels[channelId].state = state;
        channels[channelId].sequenceNumber = sequenceNumber;
    }

    function startChallengePeriod(
        bytes32 channelId,
        bytes signature,
        address signer
    ) {
        if (channels[channelId].phase != PHASE_OPEN) {
            Error("channel not open");
            return;
        }

        bytes32 fingerprint = sha3(
            "startChallengePeriod",
            channelId
        );

        if (signer == channels[channelId].address0) {
            if (!ecverify(fingerprint, signature, channels[channelId].address0)) {
                Error("signature invalid");
                return;
            }
        } else if (signer == channels[channelId].address1) {
            if (!ecverify(fingerprint, signature, channels[channelId].address1)) {
                Error("signature invalid");
                return;
            }
        } else {
            Error("signer invalid");
            return;
        }

        channels[channelId].closingBlock = block.number + channels[channelId].challengePeriod;
        channels[channelId].phase = PHASE_CHALLENGE;
    }

    function tryClose(
        bytes32 channelId
    ) {
        if (
            channels[channelId].phase == PHASE_CHALLENGE &&
            block.number > channels[channelId].closingBlock
        ) {
            channels[channelId].phase = PHASE_CLOSED;
        }
    }
}