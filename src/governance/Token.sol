// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

//import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./TokenStorage.sol";
import "../interfaces/IToken.sol";
import "./TokenTimelock.sol";

contract BitDSMToken is 
    TokenStorage,
    IToken,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    bool private _initializing;  // Declared here as implementation detail
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address initialSupplyDistributor
    ) public initializer {
        _initializing = true;
        __ERC20_init("BitDSM Token", "BDSM");
        __Ownable_init();
        _transferOwnership(initialOwner);
        __Pausable_init();
        __ReentrancyGuard_init();

        startTime = block.timestamp;
        lastEmissionTime = startTime;
        _mint(initialSupplyDistributor, INITIAL_SUPPLY);
        _initializing = false;

        guardianList = new address[](0);
    }

    /**
     * @dev Modifier to check if emissions are allowed
     */
    modifier whenEmissionsNotPaused() {
        if (emissionsPaused) revert EmissionsPausedError();
        _;
    }
 
    /**
     * @dev Pause or unpause emissions
     * @param pause True to pause, false to unpause
     */
    function setEmissionsPaused(bool pause) external onlyOwner {
        emissionsPaused = pause;
        emit EmissionsPaused(pause);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        if (!_initializing) {
            require(amount <= MAX_DAILY_MINT, "Mint amount exceeds limit");
        }
        super._mint(account, amount);
    }

        /**
     * @dev Emergency function to burn tokens if supply gets too high
     * @param amount Amount of tokens to burn from caller's balance
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Calculates and mints accumulated tokens based on days passed
     * @param distributor Address to receive the new tokens
     * @return (uint256, uint256) Amount minted and days accumulated
     */
    function emitNewTokens(address distributor) 
        external 
        nonReentrant 
        whenEmissionsNotPaused 
        returns (uint256, uint256) 
    {
        require(distributor != address(0), "Invalid distributor address");
        
        uint256 timePassed = block.timestamp - lastEmissionTime;
        require(timePassed >= 1 days, "Wait 24 hours between emissions");
        
        uint256 totalTimePassed = block.timestamp - startTime;
        require(totalTimePassed <= EMISSION_PERIOD, "Emission period ended");

        // Calculate accumulated days and amounts
        uint256 daysToEmit = timePassed / 1 days;
        uint256 totalMintAmount = 0;
        
        for(uint256 i = 0; i < daysToEmit; i++) {
            uint256 mintAmount = getNextEmissionAmount();
            if (mintAmount == 0) break;
            
            if (totalSupply() + totalMintAmount + mintAmount > TOTAL_SUPPLY) {
                mintAmount = TOTAL_SUPPLY - totalSupply() - totalMintAmount;
                totalMintAmount += mintAmount;
                break;
            }
            
            totalMintAmount += mintAmount;
        }
        
        if (totalMintAmount > 0) {
            _mint(distributor, totalMintAmount);
            emit AccumulatedEmission(
                daysToEmit,
                totalMintAmount,
                totalSupply(),
                block.timestamp
            );
        }
        
        lastEmissionTime = block.timestamp;
        return (totalMintAmount, daysToEmit);
    }

    /**
     * @dev Get information about pending emissions
     * @return pendingAmount Total amount pending to be emitted
     * @return daysAccumulated Number of days accumulated
     * @return nextDailyEmission Amount for next daily emission
     */
    function getPendingEmissions() public view returns (
        uint256 pendingAmount,
        uint256 daysAccumulated,
        uint256 nextDailyEmission
    ) {
        uint256 timePassed = block.timestamp - lastEmissionTime;
        if (timePassed < 1 days) {
            return (0, 0, getNextEmissionAmount());
        }

        uint256 daysToEmit = timePassed / 1 days;
        uint256 totalMintAmount = 0;

        for(uint256 i = 0; i < daysToEmit; i++) {
            uint256 mintAmount = getNextEmissionAmount();
            if (mintAmount == 0) break;
            
            if (totalSupply() + totalMintAmount + mintAmount > TOTAL_SUPPLY) {
                mintAmount = TOTAL_SUPPLY - totalSupply() - totalMintAmount;
                totalMintAmount += mintAmount;
                break;
            }
            
            totalMintAmount += mintAmount;
        }

        return (totalMintAmount, daysToEmit, getNextEmissionAmount());
    }

    /**
     * @dev Calculate emission amount based on days passed
     * Uses a stepwise halving period of 4 years from INITIAL_DAILY_EMISSION to a minimum of 450 tokens per day
     *  First period (0-4 years): 7,200 tokens per day
     *  Second period (4-8 years): 3,600 tokens per day
     *  Third period (8-12 years): 1,800 tokens per day
     *  Fourth period (12-16 years): 900 tokens per day
     *  Fifth period (16-20 years): 450 tokens per day
     */
    function getNextEmissionAmount() public view returns (uint256) {
        uint256 timePassed = block.timestamp - startTime;
        if (timePassed > EMISSION_PERIOD) {
            return 0;
        }

        // Calculate which halving period we're in (0-4)
        uint256 halvingPeriod = timePassed / HALVING_PERIOD;
        
        // Calculate emission with whole numbers
        uint256 emissionAmount = INITIAL_DAILY_EMISSION >> halvingPeriod;
        return emissionAmount;
    }
  
    /**
     * @dev Override transfer function to check for pause status and blacklist
     * @param to The address to transfer to
     * @param amount The amount of tokens to transfer
     * @return bool True if the transfer is successful
     */
    function transfer(address to, uint256 amount) public override (ERC20Upgradeable, IToken) whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }
    /**
     * @dev Override transferFrom function to check for pause status and blacklist
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param amount The amount of tokens to transfer
     * @return bool True if the transfer is successful
     */
    function transferFrom(address from, address to, uint256 amount) public override (ERC20Upgradeable, IToken) whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }
    /**
     * @dev Override approve function to check for pause status and blacklist
     * @param spender The address to approve
     * @param amount The amount of tokens to approve
     * @return bool True if the approval is successful
     */
    function approve(address spender, uint256 amount) public override (ERC20Upgradeable, IToken) whenNotPaused
    returns (bool) {
        return super.approve(spender, amount);
    }
    /**
     * @dev Get current emission rate and progress
     */
    function getEmissionStats() external view returns (
        uint256 currentSupply,
        uint256 remainingTime,
        uint256 nextEmission,
        bool isPaused
    ) {
        currentSupply = totalSupply();
        uint256 timePassed = block.timestamp - startTime;
        remainingTime = timePassed >= EMISSION_PERIOD ? 0 : EMISSION_PERIOD - timePassed;
        nextEmission = getNextEmissionAmount();
        isPaused = emissionsPaused;
    }

    /**
     * @dev Schedule emissions pause state change through timelock
     * @param pause True to pause, false to unpause
     */
    function scheduleSetEmissionsPaused(bool pause) external onlyOwner {
        bytes memory data = abi.encodeWithSelector(
            this.setEmissionsPaused.selector,
            pause
        );
        
        TokenTimelock timelock = TokenTimelock(payable(owner()));
        bytes32 actionId = timelock.hashOperation(
            address(this),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );
        
        timelock.schedule(
            address(this),
            0,
            data,
            bytes32(0),
            bytes32(0),
            TIMELOCK_MIN_DELAY
        );
        
        emit ActionScheduled(actionId, block.timestamp + TIMELOCK_MIN_DELAY);
    }

    /**
     * @dev Execute a scheduled timelock operation
     */
    function executeTimelockOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external {
        TokenTimelock timelock = TokenTimelock(payable(owner()));
        timelock.execute(target, value, data, predecessor, salt);
    }

    modifier onlyGuardian() {
        if (!guardians[msg.sender]) revert NotGuardian();
        _;
    }

    /**
     * @dev Schedule addition of a new guardian
     * @param guardian Address of the new guardian
     */
    function scheduleAddGuardian(address guardian) external onlyOwner {
        require(guardian != address(0), "Invalid guardian address");
        require(!guardians[guardian], "Already a guardian");
        
        bytes32 operationId = keccak256(
            abi.encodePacked("ADD_GUARDIAN", guardian, block.timestamp)
        );
        
        timelockOperations[operationId] = TimelockOperation({
            scheduledTime: block.timestamp + GUARDIAN_TIMELOCK_DELAY,
            executed: false
        });
        
        emit GuardianChangeScheduled(
            operationId,
            guardian,
            true,
            block.timestamp + GUARDIAN_TIMELOCK_DELAY
        );
    }

    /**
     * @dev Execute scheduled guardian addition with failure handling
     */
    function executeAddGuardian(bytes32 operationId, address guardian) external onlyOwner {
        TimelockOperation storage operation = timelockOperations[operationId];
        
        // Validate timelock operation
        _validateTimelockOperation(operation, "ADD_GUARDIAN", guardian);
        
        // Validate guardian requirements
        require(guardian != address(0), "Invalid guardian address");
        require(!guardians[guardian], "Already a guardian");
        
        // Add guardian
        guardians[guardian] = true;
        guardianList.push(guardian);
        
        // Mark operation as executed
        operation.executed = true;
        emit GuardianAdded(guardian);
    }

    /**
     * @dev Schedule removal of a guardian
     * @param guardian Address of the guardian to remove
     */
    function scheduleRemoveGuardian(address guardian) external onlyOwner {
        require(guardians[guardian], "Not a guardian");
        require(guardianList.length > MIN_GUARDIANS, "Cannot remove guardian below minimum");
        
        bytes32 operationId = keccak256(
            abi.encodePacked("REMOVE_GUARDIAN", guardian, block.timestamp)
        );
        
        timelockOperations[operationId] = TimelockOperation({
            scheduledTime: block.timestamp + GUARDIAN_TIMELOCK_DELAY,
            executed: false
        });
        
        emit GuardianChangeScheduled(
            operationId,
            guardian,
            false,
            block.timestamp + GUARDIAN_TIMELOCK_DELAY
        );
    }

    /**
     * @dev Execute scheduled guardian removal with failure handling
     */
    function executeRemoveGuardian(bytes32 operationId, address guardian) external onlyOwner {
        TimelockOperation storage operation = timelockOperations[operationId];
        
        // Validate timelock operation
        _validateTimelockOperation(operation, "REMOVE_GUARDIAN", guardian);
        
        // Validate guardian requirements
        require(guardians[guardian], "Not a guardian");
        require(guardianList.length > MIN_GUARDIANS, "Cannot remove guardian below minimum");
        
        // Remove guardian
        guardians[guardian] = false;
        for (uint i = 0; i < guardianList.length; i++) {
            if (guardianList[i] == guardian) {
                guardianList[i] = guardianList[guardianList.length - 1];
                guardianList.pop();
                break;
            }
        }
        
        // Mark operation as executed
        operation.executed = true;
        emit GuardianRemoved(guardian);
    }

    /**
     * @dev Internal function to validate timelock operations
     * @param operation The timelock operation to validate
     * @param operationType The type of operation being validated
     * @param guardian The guardian address involved in the operation
     */
    function _validateTimelockOperation(
        TimelockOperation memory operation,
        string memory operationType,
        address guardian
    ) internal view{
        bytes32 expectedOperationId = keccak256(
            abi.encodePacked(operationType, guardian, operation.scheduledTime - GUARDIAN_TIMELOCK_DELAY)
        );
        
        if (operation.scheduledTime == 0) revert OperationNotScheduled();
        if (operation.executed) revert OperationAlreadyExecuted();
        if (block.timestamp < operation.scheduledTime) revert TimelockNotReady();
        
        // Verify operation matches expected parameters
        require(
            keccak256(abi.encodePacked(operationType, guardian, operation.scheduledTime - GUARDIAN_TIMELOCK_DELAY)) == expectedOperationId,
            "Invalid operation parameters"
        );
    }

    /**
     * @dev Propose an emergency pause of all token operations
     */
    function proposeEmergencyPause() external onlyGuardian {
        require(!paused(), "Already paused");
        bytes32 actionId = keccak256(abi.encodePacked("PAUSE", block.timestamp));
        _initializeEmergencyAction(actionId);
        emit EmergencyActionProposed(actionId, "PAUSE");
    }

    /**
     * @dev Propose an emergency unpause of token operations
     */
    function proposeEmergencyUnpause() external onlyGuardian {
        require(paused(), "Not paused");
        bytes32 actionId = keccak256(abi.encodePacked("UNPAUSE", block.timestamp));
        _initializeEmergencyAction(actionId);
        emit EmergencyActionProposed(actionId, "UNPAUSE");
    }

    /**
     * @dev Propose an emergency burn of tokens from a specific address
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function proposeEmergencyBurn(address from, uint256 amount) external onlyGuardian {
        bytes32 actionId = keccak256(abi.encodePacked("BURN", from, amount, block.timestamp));
        _initializeEmergencyAction(actionId);
        emit EmergencyActionProposed(actionId, "BURN");
    }

    /**
     * @dev Approve an emergency action
     * @param actionId ID of the action to approve
     */
    function approveEmergencyAction(bytes32 actionId) external onlyGuardian {
        EmergencyAction storage action = emergencyActions[actionId];
        require(action.proposedTime != 0, "Action does not exist");
        require(!action.executed, "Action already executed");
        require(block.timestamp <= action.proposedTime + EMERGENCY_ACTION_TIMEOUT, "Action expired");
        
        if (action.hasApproved[msg.sender]) revert AlreadyApproved();
        
        action.hasApproved[msg.sender] = true;
        action.approvals += 1;
        
        emit EmergencyActionApproved(actionId, msg.sender);
    }

    /**
     * @dev Execute an emergency pause action with failure handling
     */
    function executeEmergencyPause(bytes32 actionId) external onlyGuardian {
        // First validate the action - will revert if invalid
        (bool validationSuccess, string memory validationError) = _validateEmergencyActionWithError(actionId);
        if (!validationSuccess) {
            emit EmergencyActionFailed(actionId, "PAUSE", validationError);
            return;
        }
        
        // Attempt to pause
        bool success = _attemptPause();
        
        if (success) {
            _markActionExecuted(actionId);
        } else {
            emit EmergencyActionFailed(actionId, "PAUSE", "Pause operation failed. The token is already paused.");
        }
    }

    /**
     * @dev Internal function to attempt pause operation
     * @return success Whether the pause operation succeeded
     */
    function _attemptPause() private returns (bool) {
        if (paused()) {
            return false;
        }
        _pause();
        return true;
    }
    /**
     * @dev Internal function to attempt pause operation
     * @return success Whether the unpause operation succeeded
     */
    function _attemptUnpause() private returns (bool) {
        if (!paused()) {
            return false;
        }
        _unpause();
        return true;
    }

    /**
     * @dev Execute an emergency unpause action with failure handling
     */
    function executeEmergencyUnpause(bytes32 actionId) external onlyGuardian {
       // Validate the action and capture any error
        (bool validationSuccess, string memory validationError) = _validateEmergencyActionWithError(actionId);
        if (!validationSuccess) {
            emit EmergencyActionFailed(actionId, "UNPAUSE", validationError);
            return;
        }
            
        // Attempt to unpause
        bool success = _attemptUnpause();
        
        if (success) {
            _markActionExecuted(actionId);
        } else {
            emit EmergencyActionFailed(
                actionId,
                "UNPAUSE",
                "Unpause operation failed. The token is already unpaused."
            );
        }
    }

    /**
     * @dev Execute an emergency burn action with failure handling
     */
    // function executeEmergencyBurn(
    //     bytes32 actionId,
    //     address from,
    //     uint256 amount
    // ) external onlyGuardian {
    //     (bool validationSuccess, string memory validationError) = _validateEmergencyActionWithError(actionId);
    //     if (!validationSuccess) {
    //         emit EmergencyActionFailed(actionId, "BURN", validationError);
    //         return;
    //     }

    //     // Attempt to burn tokens
    //     bool success = _burn(from, amount);
        
    //     if (success) {
    //         emit EmergencyTokensBurned(from, amount);
    //         _markActionExecuted(actionId);
    //     } else {
    //         emit EmergencyActionFailed(
    //             actionId,
    //             "BURN",
    //             "Burn operation failed"
    //         );
    //     }
    // }

    /**
     * @dev Emergency withdrawal of stuck tokens
     * @param token Address of the token to withdraw (zero address for ETH)
     * @param to Address to send the tokens to
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyGuardian {
        bytes32 actionId = keccak256(abi.encodePacked("WITHDRAW", token, to, amount, block.timestamp));
        (bool validationSuccess, string memory validationError) = _validateEmergencyActionWithError(actionId);
        
        if (!validationSuccess) {
            emit EmergencyActionFailed(actionId, "WITHDRAW", validationError);
            return;
        }
        
        if (token == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20Upgradeable(token).transfer(to, amount);
        }
        
        emit EmergencyWithdrawal(token, to, amount);
        _markActionExecuted(actionId);
    }

    // Internal helper functions
    function _initializeEmergencyAction(bytes32 actionId) internal {
        require(block.timestamp >= lastEmergencyAction + EMERGENCY_COOLDOWN, "Emergency cooldown not passed");
        EmergencyAction storage action = emergencyActions[actionId];
        action.proposedTime = block.timestamp;
        action.approvals = 1;
        action.hasApproved[msg.sender] = true;
    }

    /**
     * @dev Internal function to validate emergency action with error handling
     * @return success Whether the validation succeeded
     * @return errorMessage Error message if validation failed
     */
    function _validateEmergencyActionWithError(bytes32 actionId) internal view returns (bool, string memory) {
        EmergencyAction storage action = emergencyActions[actionId];
        
        if (action.proposedTime == 0) return (false, "Action does not exist");
        if (action.executed) return (false, "Action already executed");
        if (block.timestamp > action.proposedTime + EMERGENCY_ACTION_TIMEOUT) return (false, "Action expired");
        if (action.approvals < MIN_GUARDIANS) return (false, "Insufficient approvals");
        
        return (true, "");
    }

    function _markActionExecuted(bytes32 actionId) internal {
        EmergencyAction storage action = emergencyActions[actionId];
        action.executed = true;
        lastEmergencyAction = block.timestamp;
        emit EmergencyActionExecuted(actionId);
    }

    
    /**
     * @dev Cancel a scheduled timelock operation
     */
    function cancelTimelockOperation(
        bytes32 operationId,
        address guardian,
        string memory operationType
    ) external onlyOwner {
        TimelockOperation storage operation = timelockOperations[operationId];
        require(operation.scheduledTime != 0, "Operation does not exist");
        require(!operation.executed, "Operation already executed");
        
        delete timelockOperations[operationId];
        
        emit TimelockOperationCancelled(
            operationId,
            guardian,
            operationType
        );
    }

    /**
     * @dev Get detailed emission statistics
     * @return currentSupply Current total supply
     * @return pendingEmissions Amount of pending emissions
     * @return daysAccumulated Number of days accumulated
     * @return nextEmission Next daily emission amount
     * @return remainingTime Time until emission period ends
     */
    function getDetailedEmissionStats() external view returns (
        uint256 currentSupply,
        uint256 pendingEmissions,
        uint256 daysAccumulated,
        uint256 nextEmission,
        uint256 remainingTime
    ) {
        currentSupply = totalSupply();
        (pendingEmissions, daysAccumulated, nextEmission) = getPendingEmissions();
        uint256 timePassed = block.timestamp - startTime;
        remainingTime = timePassed >= EMISSION_PERIOD ? 0 : EMISSION_PERIOD - timePassed;
    }
    /**
     * @dev Returns the list of guardian addresses
     * @return guardianList Array of guardian addresses
     */
    function getGuardianList() external view returns (address[] memory) {
        return guardianList;
    }
    function getStartTime() external view returns (uint256) {
        return startTime;
    }
    function getLastEmissionTime() external view returns (uint256) {
        return lastEmissionTime;
    }
    function getTotalSupply() external pure returns (uint256) {
        return TOTAL_SUPPLY;
    }
    function getEmissionsPaused() external view returns (bool) {
        return emissionsPaused;
    }
    function getGuardians(address) external view returns (bool) {
        return guardians[msg.sender];
    }
}
