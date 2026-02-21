// SHARED CODE START

using EIP712HashOptimized as B;

// Contract A (currentContract) state model
ghost mapping(uint => uint) contractAState;
// State of contract A (currentContract) that has been written to already, so we don't track its reads anymore
ghost mapping(uint => bool) killedFlagA;

// Contract B state model
ghost mapping(uint => uint) contractBState;
// State of contract B that has been written to already, so we don't track its reads anymore
ghost mapping(uint => bool) killedFlagB;

// update first-time reads
hook ALL_SLOAD(uint loc) uint value {
   if(executingContract == currentContract && !killedFlagA[loc]) {
       require contractAState[loc] == value;
   } else if(executingContract == B && !killedFlagB[loc]) {
       require contractBState[loc] == value;
   }
}

// update writes
hook ALL_SSTORE(uint loc, uint value) {
   if(executingContract == currentContract) {
      killedFlagA[loc] = true;
   } else if(executingContract == B) {
      killedFlagB[loc] = true;
   }
}

// assume the two contracts have the same state and address
function assume_equivalent_states() {
    // no slot has been read yet
    require forall uint i. !killedFlagA[i];
    require forall uint i. !killedFlagB[i];
    // same state
    require forall uint i. contractAState[i] == contractBState[i];
    // same address
    require currentContract == B;
}

// sets everything but the callee the same in two environments
function e_equivalence(env e1, env e2) {
    require e1.msg.sender == e2.msg.sender;
    require e1.block.timestamp == e2.block.timestamp;
    require e1.msg.value == e2.msg.value;
    require e1.block.number == e2.block.number;
    // require e1.msg.data == e2.msg.data;
}
// SHARED CODE END

// RULES START
rule equivalence_of_revert_conditions()
{
    storage init = lastStorage;
    assume_equivalent_states();
    bool hashTokenizedMint_EIP712HashCorrect_revert;
    bool hashTokenizedMint_EIP712HashOptimized_revert;
    // using this as opposed to generating input parameters is experimental
    env e_hashTokenizedMint_EIP712HashCorrect; calldataarg args;
    env e_hashTokenizedMint_EIP712HashOptimized;
    e_equivalence(e_hashTokenizedMint_EIP712HashCorrect, e_hashTokenizedMint_EIP712HashOptimized);

    hashTokenizedMint@withrevert(e_hashTokenizedMint_EIP712HashCorrect, args);
    hashTokenizedMint_EIP712HashCorrect_revert = lastReverted;

    B.hashTokenizedMint@withrevert(e_hashTokenizedMint_EIP712HashOptimized, args) at init;
    hashTokenizedMint_EIP712HashOptimized_revert = lastReverted;

    assert(hashTokenizedMint_EIP712HashCorrect_revert == hashTokenizedMint_EIP712HashOptimized_revert);
}

rule equivalence_of_return_value()
{
    storage init = lastStorage;
    assume_equivalent_states();
    bytes32 hashTokenizedMint_EIP712HashCorrect_bytes32_out0;
    bytes32 hashTokenizedMint_EIP712HashOptimized_bytes32_out0;

    env e_hashTokenizedMint_EIP712HashCorrect; calldataarg args;
    env e_hashTokenizedMint_EIP712HashOptimized;

    e_equivalence(e_hashTokenizedMint_EIP712HashCorrect, e_hashTokenizedMint_EIP712HashOptimized);

    hashTokenizedMint_EIP712HashCorrect_bytes32_out0 = hashTokenizedMint(e_hashTokenizedMint_EIP712HashCorrect, args);
    hashTokenizedMint_EIP712HashOptimized_bytes32_out0 = B.hashTokenizedMint(e_hashTokenizedMint_EIP712HashOptimized, args) at init;

    assert(hashTokenizedMint_EIP712HashCorrect_bytes32_out0 == hashTokenizedMint_EIP712HashOptimized_bytes32_out0);
}
