pragma solidity ^0.5.0;

/**
 * @dev Interface of CERC20 functions from Compound documentation: https://compound.finance/developers
 */
interface CERC20 {
    /**
     * @dev Mints new CERC20, analagous to supply in Compound v1.
     * Returns 0 on success, otherwise an error code
     */
    function mint(uint mintAmount) external returns (uint);

    /**
     * @dev Redeems the underlying for previously minted cTokens.
     * Returns 0 on success, otherwise an error code
     */
    function redeem(uint redeemTokens) external returns (uint);

    function balanceOf(address account) external returns (uint);

    function exchangeRateCurrent() external returns (uint);

}