// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEthereumPool {
    /*=============== Events ========================*/
    /// @notice An event thats emitted when LPTTFF token mint
    event MintLPTTFFTokenToUser(address _userAddress, uint256 _lpTtffQuantity);
    /// @notice An event thats emitted when sending for Weth to UniswapV2Adapter Contract
    event SendWETHtoLiquidity(address _recipient, uint256 _amount);
    /// @notice An event thats emitted when TTFF created
    event TTFFCreated(address _ttff, uint256 _amount);

    /*=============== Functions ========================*/
    /// @notice It is for Protocol Gradual contract.
    /// @dev Sends Weth to Protocol Vault, if needs.
    /// @dev It is triggered by the Protocol Gradual contract.
    function feedVault(uint256 _amount) external returns (bool);

    /// @dev Read in TTFF process
    /// @return Issue quantity 
    function _issueQuantity() external view returns (uint256);

    /// @notice Increases the limit.
    /// @dev Triggers after Weth transfer from the Protocol Vault contract.
    function addLimit(uint256 _limit) external;
}
