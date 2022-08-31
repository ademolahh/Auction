//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library Lib {
    function _removeElement(address[] storage array, address _addr)
        external
        returns (uint256 i)
    {
        uint256 length = array.length;
        for (; i < length; ++i) {
            if (array[i] == _addr) {
                array[i] = array[length - 1];
                array.pop();
                break;
            }
        }
    }
}
