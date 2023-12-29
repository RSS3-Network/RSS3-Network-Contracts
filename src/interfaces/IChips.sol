// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IChips {
    /**
     * @notice Initializes the Chips contract.
     * @param staking_ Address of the Staking contract.
     */
    function initialize(address staking_) external;

    /**
     * @notice Mints a token to `account`.
     * @param account Address to receive the minted token.
     * @return tokenId The new minted token id.
     */
    function mint(address account) external returns (uint256 tokenId);

    /**
     * @notice Mints a batch tokens to `account`.
     * @param to Address to receive the minted tokens.
     * @param batchSize Number of tokens to mint.
     * @return startTokenId The start of new minted chips token ids.
     * @return endTokenId The end of new minted chips token ids.
     */
    function mintBatch(
        address to,
        uint256 batchSize
    ) external returns (uint256 startTokenId, uint256 endTokenId);

    /**
     * @notice Destroys `tokenId`.
     * @param tokenId ID of token to burn.
     */
    function burn(uint256 tokenId) external;

    /**
     * @notice Returns total supply of tokens.
     * @return Total supply of tokens.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice  Returns the address of the Staking contract.
     * @return Address of the Staking contract.
     */
    function stakingContract() external view returns (address);
}
