// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Counter {
    suint256 private number;

    event NumberChanged(uint256 newNumber);

    function setNumber(suint256 newNumber) external {
        number = newNumber;
        emit NumberChanged(uint256(newNumber));
    }

    function increment() external {
        number = number + suint256(1);
        emit NumberChanged(uint256(number));
    }

    function decrement() external {
        require(number > suint256(0), "Counter: underflow");
        number = number - suint256(1);
        emit NumberChanged(uint256(number));
    }

    function getNumber() external view returns (uint256) {
        return uint256(number);
    }
}
