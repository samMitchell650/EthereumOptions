pragma solidity ^0.5.0;

import "./compound_interfaces/CETH.sol";
import "./compound_interfaces/CERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract CETHCallOption is ERC20, ERC20Detailed {
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

    function exerciseOption(address payable exercisor, uint256 amount) public beforeExpiration returns (bool success) {
        if(exercisor != msg.sender){
            require(allowance(exercisor, msg.sender) >= amount, "Unauthorized exercise");
        }
        require(balanceOf(exercisor) >= amount, "Not enough option tokens owned");
        _burn(exercisor, amount);
        uint256 dai_to_exercise = amount.mul(_strike);
        require(DAI_CONTRACT.transferFrom(exercisor, address(this), dai_to_exercise), "DAI transfer unsuccessful");
        exercisor.transfer(amount);
        require(CDAI_CONTRACT.mint(dai_to_exercise) == 0, "Minting of cDAI tokens unsuccessful");
        emit OptionExercised(exercisor, amount);

        return true;
    }
    
    function writeOption() public payable beforeExpiration returns (bool success) {
        require(msg.value > 0, "Must send eth to write option");
        _mint(msg.sender, msg.value);
        uint256 ceth_balance_before = CETH_CONTRACT.balanceOf(address(this));
        CETH_CONTRACT.mint.value(msg.value)();
        uint256 ceth_balance_after = CETH_CONTRACT.balanceOf(address(this));
        _contributions[msg.sender] = ceth_balance_after - ceth_balance_before;
        _total_contribution.add(ceth_balance_after - ceth_balance_before);
        emit OptionWrote(msg.sender, msg.value);
        
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
