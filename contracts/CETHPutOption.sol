pragma solidity ^0.5.0;

import "./compound_interfaces/CETH.sol";
import "./compound_interfaces/CERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract CETHPutOption is ERC20, ERC20Detailed {
    using SafeMath for uint256;
    
    uint256 private _expiration_timestamp;
    uint256 private _strike;
    
    mapping(address => uint) private _contributions;
    uint256 private _total_contribution;
    
    ERC20 constant private DAI_CONTRACT = ERC20(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    CERC20 constant private CDAI_CONTRACT = CERC20(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    CETH constant private CETH_CONTRACT = CETH(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    
    event OptionExercised(address indexed owner, uint256 amount);
    event OptionWrote(address indexed writer, uint256 amount);

    constructor(uint256 expiration_timestamp, uint256 strike, string memory name, string memory symbol)
        ERC20Detailed(name, symbol, 18)
        public
        payable
    {
        _expiration_timestamp = expiration_timestamp;
        _strike = strike;
    }
    
    function contribution(address contributor) public view returns (uint256) {
        return _contributions[contributor];
    }
    
    modifier beforeExpiration() {
        require(block.timestamp <= _expiration_timestamp, "Option contract has expired.");
        _;
    }

    function exerciseOption(address exercisor, uint256 amount) public payable beforeExpiration returns (bool success) {
        if(exercisor != msg.sender){
            require(allowance(exercisor, msg.sender) >= amount, "Unauthorized exercise");
        }
        require(msg.value >= amount, "Not ETH sent to exercise");
        require(balanceOf(exercisor) >= amount, "Not enough option tokens owned");
        _burn(exercisor, amount);
        CETH_CONTRACT.mint.value(amount)();
        uint256 dai_collateral = amount.mul(_strike);
        uint256 exchange_rate = CDAI_CONTRACT.exchangeRateCurrent();
        uint256 cdai_to_dai_collateral = dai_collateral.div(exchange_rate);
        require(CDAI_CONTRACT.redeem(cdai_to_dai_collateral) == 0, "Redeeming of cDAI tokens unsuccessful");
        require(DAI_CONTRACT.transferFrom(address(this), exercisor, dai_collateral), "DAI transfer unsuccessful");
        emit OptionExercised(exercisor, amount);

        return true;
    }
    
    function writeOption(uint256 amount) public beforeExpiration returns (bool success) {
        require(amount > 0, "Must write put option for at least 1 wei");
        _contributions[msg.sender] = amount;
        _total_contribution.add(amount);
        _mint(msg.sender, amount);
        uint256 dai_collateral = amount.mul(_strike);
        require(DAI_CONTRACT.transferFrom(msg.sender, address(this), dai_collateral), "DAI transfer unsuccessful");
        require(CDAI_CONTRACT.mint(dai_collateral) == 0, "Minting of cDAI tokens unsuccessful");
        emit OptionWrote(msg.sender, amount);
        
        return true;
    }
    
    modifier afterExpiration() {
        require(block.timestamp > _expiration_timestamp, "Option contract has not expired.");
        _;
    }
    
    function claimContribution() public afterExpiration returns (bool success) {

        require(_contributions[msg.sender] > 0, "No contribution found");
        
        uint256 total_balance_ceth = CETH_CONTRACT.balanceOf(address(this));
        uint256 claimer_proportion_ceth_num = total_balance_ceth.mul(_contributions[msg.sender]);
        uint256 claimer_proportion_ceth = claimer_proportion_ceth_num.div(_total_contribution);

        uint256 total_balance_cdai = CDAI_CONTRACT.balanceOf(address(this));
        uint256 claimer_proportion_cdai_num = total_balance_cdai.mul(_contributions[msg.sender]);
        uint256 claimer_proportion_cdai = claimer_proportion_cdai_num.div(_total_contribution);

        _total_contribution.sub(_contributions[msg.sender]);
        _contributions[msg.sender] = 0;

        if(claimer_proportion_cdai > 0){
            uint256 balanceBefore = DAI_CONTRACT.balanceOf(address(this));
            require(CDAI_CONTRACT.redeem(claimer_proportion_cdai) == 0, "Redeeming of cDAI tokens unsuccessful");
            uint256 balanceAfter = DAI_CONTRACT.balanceOf(address(this));
            DAI_CONTRACT.transfer(msg.sender, balanceAfter.sub(balanceBefore));
        }
        
        if(claimer_proportion_ceth > 0){
            uint256 balanceBefore = address(this).balance;
            require(CETH_CONTRACT.redeem(claimer_proportion_ceth) == 0, "Redeeming of cETH tokens unsuccessful");
            uint256 balanceAfter = address(this).balance;
            msg.sender.transfer(balanceAfter.sub(balanceBefore));
        }
        
        return true;
    }
    
    function deleteContract() public afterExpiration {

        uint256 total_balance_ceth = CETH_CONTRACT.balanceOf(address(this));
        uint256 total_balance_cdai = CDAI_CONTRACT.balanceOf(address(this));
        
        if(total_balance_ceth == 0 && total_balance_cdai == 0){
            selfdestruct(msg.sender);
        }
    }

}
