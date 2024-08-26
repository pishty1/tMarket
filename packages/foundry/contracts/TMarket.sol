//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "CMTAT/contracts/CMTAT_PROXY.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TMarket {
  struct RightsDisposalOrder {
    address seller;
    address tokenAddress;
    uint256 units;
    uint256 tradeValuePerUnit; // price in pennies per unit
    uint256 expirationDate;
  }

  // be aware of where usdc contract is
  address usdc;

  RightsDisposalOrder[] private orders;
  // add counter
  uint256 public orderCount;

  uint256 shareCounter;

  constructor(address usdc_) {
    usdc = usdc_;
  }

  function createOrder(
    address tokenAddress,
    uint256 units,
    uint256 tradeValuePerUnit,
    uint256 expirationDate
  ) external {
    orders.push(
      RightsDisposalOrder(
        msg.sender, tokenAddress, units, tradeValuePerUnit, expirationDate
      )
    );
    orderCount++;
  }

  function getOrder(
    uint256 index
  ) external view returns (RightsDisposalOrder memory) {
    return orders[index];
  }

  function buyOrder(uint256 index) external {
    RightsDisposalOrder storage order = orders[index];
    require(order.expirationDate >= block.timestamp, "Order expired");
    // transfer the usdc to the seller
    uint256 price = order.tradeValuePerUnit * order.units;
    IERC20(usdc).transferFrom(msg.sender, order.seller, price);

    CMTAT_PROXY(order.tokenAddress).transferFrom(
      order.seller, msg.sender, order.units
    );
    console.log(order.units);
  }

  // here we will conver the number of rights to offered shares
  function redeemRightsForOfferedShares(
    address rightsTokenAddress,
    address offeredSharesAddress,
    uint256 units
  ) external payable {
    (uint256 first,) = CMTAT_PROXY(offeredSharesAddress).getRightsRatio();
    uint256 shares = units / first;
    // get the price of the offered shares
    uint256 price = CMTAT_PROXY(offeredSharesAddress).getPricePerShare();
    // now calculate the total price of the shares
    uint256 totalPrice = shares * price;
    console.log(totalPrice);
    // check the user has sent enough money to buy the shares
    require(msg.value == totalPrice, "Incorrect value, should be ");
    // now transfer the shares to the user
    CMTAT_PROXY(offeredSharesAddress).mint(msg.sender, shares);
    shareCounter = shareCounter + shares;
    CMTAT_PROXY(rightsTokenAddress).burn(
      msg.sender, units, "redeem rights for offered shares"
    );
  }
}
