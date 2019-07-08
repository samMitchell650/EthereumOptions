pragma solidity ^0.5.0;

/**
 * @dev Interface of CETH functions from Compound documentation: https://compound.finance/developers
 */
interface CETH {
    /**
     * @dev Mints new CETH, analagous to supply in Compound v1.
     */
    function mint() external payable;

    /**
     * @dev Redeems the underlying for previously minted cTokens.
     * Returns 0 on success, otherwise an error code
     */
    function redeem(uint redeemTokens) external returns (uint);

    function balanceOf(address account) external returns (uint);

    function exchangeRateCurrent() external returns (uint);

}