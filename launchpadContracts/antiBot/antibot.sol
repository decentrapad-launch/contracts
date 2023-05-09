// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IDecentraAntiBot.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract DecentraAntiBot {
    event BoughtEarly(address indexed sniper);
    event BlockList(address tokenAddress, uint256 usersLength, bool status);
    event ValuesAssigned(address poolAddress);
    // Anti-bot and anti-whale mappings and variables
    mapping(address => mapping(address => uint256))
        public _holderLastTransferTimestamp;
    mapping(address => mapping(address => bool))
        public _isExcludedMaxTransactionAmount;
    mapping(address => mapping(address => bool))
        public automatedMarketMakerPairs;
    mapping(address => mapping(address => bool)) public blocked;

    struct tokenData {
        address owner;
        IUniswapV2Router02 routerAddress;
        address pairAddress;
        uint256 maxAmountPerTrade;
        uint256 amountAddedPerBlock;
        uint256 maxWallet;
        uint256 timeLimitPerTrade;
        uint256 launchBlock;
        uint256 deadBlocks;
        bool transferDelayEnabled;
        bool limitsInEffect;
        bool tradingEnabled;
    }

    mapping(address => tokenData) tokenAntiBotData;

    modifier onlyOwner(address tokenAddress) {
        require(
            tokenAntiBotData[tokenAddress].owner == msg.sender,
            "caller not owner of token"
        );
        _;
    }

    constructor() {}

    function setTokenOwner(address _owner) external {
        require(
            tokenAntiBotData[msg.sender].owner == address(0),
            "already set"
        );
        tokenAntiBotData[msg.sender].owner = _owner;
    }

    function setTradingEnabled(
        address tokenAddress,
        address _tokenB,
        IUniswapV2Router02 _v2router,
        bool status
    ) external onlyOwner(tokenAddress) {
        address pair = _getPair(_v2router, tokenAddress, _tokenB);
        require(pair != address(0), "no pair created");
        if (IERC20(pair).totalSupply() == 0) {
            tokenAntiBotData[tokenAddress].tradingEnabled = status;
        } else {
            require(status != true, "liquidity already added");
            tokenAntiBotData[tokenAddress].tradingEnabled = status;
        }
    }

    function _getPair(
        IUniswapV2Router02 router,
        address tokenA,
        address tokenB
    ) internal view returns (address) {
        return IUniswapV2Factory(router.factory()).getPair(tokenA, tokenB);
    }

    function transferValidation(
        address from,
        address to,
        uint256 amount
    ) external {
        address tokenAddress = msg.sender;
        if (tokenAntiBotData[tokenAddress].tradingEnabled) {
            require(!blocked[tokenAddress][from], "Sniper blocked");
            // make this simpler
            tokenAntiBotData[tokenAddress].maxAmountPerTrade += ((block.number -
                tokenAntiBotData[tokenAddress].launchBlock) *
                tokenAntiBotData[tokenAddress].amountAddedPerBlock);
            address router = address(
                tokenAntiBotData[tokenAddress].routerAddress
            );
            if (tokenAntiBotData[tokenAddress].limitsInEffect) {
                if (
                    from != tokenAntiBotData[tokenAddress].owner &&
                    to != tokenAntiBotData[tokenAddress].owner &&
                    to != address(0) &&
                    to != address(0xdead)
                ) {
                    if (
                        block.number <=
                        tokenAntiBotData[tokenAddress].launchBlock +
                            tokenAntiBotData[tokenAddress].deadBlocks &&
                        from ==
                        address(tokenAntiBotData[tokenAddress].pairAddress) &&
                        to != router &&
                        to != address(this) &&
                        to !=
                        address(tokenAntiBotData[tokenAddress].pairAddress)
                    ) {
                        blocked[tokenAddress][to] = true;
                        emit BoughtEarly(to);
                    }

                    // at launch if the transfer delay is enabled, ensure the block timestamps for purchasers is set -- during launch.
                    if (tokenAntiBotData[tokenAddress].transferDelayEnabled) {
                        if (
                            to != tokenAntiBotData[tokenAddress].owner &&
                            to != router &&
                            to !=
                            address(tokenAntiBotData[tokenAddress].pairAddress)
                        ) {
                            require(
                                _holderLastTransferTimestamp[tokenAddress][
                                    tx.origin
                                ] +
                                    tokenAntiBotData[tokenAddress]
                                        .timeLimitPerTrade <
                                    block.number,
                                "Transfer Delay enabled.  Only one purchase per block allowed."
                            );
                            _holderLastTransferTimestamp[tokenAddress][
                                tx.origin
                            ] = block.number;
                        }
                    }

                    //when buy
                    if (
                        automatedMarketMakerPairs[tokenAddress][from] &&
                        !_isExcludedMaxTransactionAmount[tokenAddress][to]
                    ) {
                        require(
                            amount <=
                                tokenAntiBotData[tokenAddress]
                                    .maxAmountPerTrade,
                            "Buy transfer amount exceeds the maxTransactionAmount."
                        );
                        require(
                            amount + IERC20(tokenAddress).balanceOf(to) <=
                                tokenAntiBotData[tokenAddress].maxWallet,
                            "Max wallet exceeded"
                        );
                    }
                    //when sell
                    else if (
                        automatedMarketMakerPairs[tokenAddress][to] &&
                        !_isExcludedMaxTransactionAmount[tokenAddress][from]
                    ) {
                        require(
                            amount <=
                                tokenAntiBotData[tokenAddress]
                                    .maxAmountPerTrade,
                            "Sell transfer amount exceeds the maxTransactionAmount."
                        );
                    } else if (
                        !_isExcludedMaxTransactionAmount[tokenAddress][to]
                    ) {
                        require(
                            amount + IERC20(tokenAddress).balanceOf(to) <=
                                tokenAntiBotData[tokenAddress].maxWallet,
                            "Max wallet exceeded"
                        );
                    }
                }
            }
        }
    }

    function setValues(
        address tokenAddress,
        address _tokenB,
        IUniswapV2Router02 router,
        uint256 _limitPerTrade,
        uint256 _maxWallet,
        uint256 _deadBlocks,
        uint256 _timeLimitPerTrade,
        uint256 _amountAddedPerBlock
    ) external onlyOwner(tokenAddress) {
        address pairAddress = _getPair(router, tokenAddress, _tokenB);
        require(pairAddress.totalSupply() == 0, "LP Already Added");
        if (pairAddress == address(0)) {
            pairAddress = IUniswapV2Factory(router.factory()).createPair(
                tokenAddress,
                _tokenB
            );
        }
        automatedMarketMakerPairs[tokenAddress][pairAddress] = true;
        tokenAntiBotData[tokenAddress].routerAddress = router;
        tokenAntiBotData[tokenAddress].maxAmountPerTrade = _limitPerTrade;
        tokenAntiBotData[tokenAddress].timeLimitPerTrade = _timeLimitPerTrade;
        tokenAntiBotData[tokenAddress]
            .amountAddedPerBlock = _amountAddedPerBlock;
        tokenAntiBotData[tokenAddress].maxWallet = _maxWallet;
        tokenAntiBotData[tokenAddress].launchBlock = block.number;
        tokenAntiBotData[tokenAddress].deadBlocks = _deadBlocks;
        tokenAntiBotData[tokenAddress].transferDelayEnabled = true;
        tokenAntiBotData[tokenAddress].limitsInEffect = true;
        tokenAntiBotData[tokenAddress].pairAddress = pairAddress;
        emit ValuesAssigned(pairAddress);
    }

    function updateBlocklist(
        address tokenAddress,
        address[] memory _users,
        bool _status
    ) external onlyOwner(tokenAddress) {
        for (uint256 i = 0; i < _users.length; i++) {
            blocked[tokenAddress][_users[i]] = _status;
        }
        emit BlockList(tokenAddress, _users.length, _status);
    }
}
