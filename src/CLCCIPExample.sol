// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*///////////////////////////////////
            Imports
///////////////////////////////////*/
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CCIPReceiver } from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";

/*///////////////////////////////////
           Interfaces
///////////////////////////////////*/
import { IRouterClient } from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*///////////////////////////////////
           Libraries
///////////////////////////////////*/
import { Client } from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
        *@title Chainlink CCIP Example
        *@notice Simple project to exemplify CCIP usage
        *@dev Do not use this contract in production
        *@author i3arba - 77 Innovation Labs
*/
contract CLCCIPExample is CCIPReceiver, Ownable{

    /*///////////////////////////////////
            Type declarations
    ///////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*///////////////////////////////////
                Variables
    ///////////////////////////////////*/
    ///@notice struct store all information related to each student
    struct Profile {
        address mainnetAddress;
        Courses course;
    }

    ///@notice struct to store information related to Courses.
    struct Courses {
        uint256 courseId;
        uint256 score;
        address examSubmission;
    }

    ///@notice Immutable variable to store the Chainlink LINK token address
    IERC20 immutable i_link;

    ///@notice variable to control the status of the control.
    //If (1)true, it becomes the main contract and can send cross-chain messages
    //if (2)false, it is only a receiver.
    uint8 public s_mainChain;

    ///@notice mapping to store student profiles
    mapping(address user => Profile) s_userProfile;
    ///@notice mapping to store the allowlisted chains to send message to this contract
    mapping(uint64 chainSelector => bool isAllowed) s_allowlistedSourceChains;
    ///@notice mapping to store the allowlisted contract to send messages from a specific chain
    mapping(uint64 chainSelector => address sender ) s_allowlistedSenders;

    uint64[] s_allowlistedReceivers;

    /*///////////////////////////////////
                Events
    ///////////////////////////////////*/
    ///@notice event emitted when a Student profile is created
    event CLCCIPExample_StudentProfileCreated(address callerTestnetAddress, address mainnetAddress);
    ///@notice event emitted when a Student profile is updated
    event CLCCIPExample_StudentProfileUpdated(address student, address newStudentAddress);
    ///@notice event emitted when a ccip message is received
    event CLCCIPExample_MessageReceived(bytes32 messageId, uint64 sourceChainSelector, Profile profile);
    ///@notice event emitted when a new source chain is enabled
    event CLCCIPExample_NewChainAllowlisted(uint64 chainSelector);
    ///@notice event emitted when a chain is removed from whitelist
    event CLCCIPExample_ChainRemoved(uint64 chainSelector);
    ///@notice event emitted when a new sender is added to a chain
    event CLCCIPExample_AllowedSenderUpdatedForTheFollowingChain(uint64 sourceChainSelector, address sender);
    ///@notice event emitted when a new CCIP message is sent
    event CLCCIPExample_MessageSent(bytes32 messageId, uint64 destinationChainSelector, address user,uint256 fees);
    ///@notice event emitted when the source of truth(sender contract) changes
    event CLCCIPExample_CoreFunctionalityChanged(uint8 mainChain);

    /*///////////////////////////////////
                Errors
    ///////////////////////////////////*/
    ///@notice error emitted when the student profile was already created
    error CLCCIPExample_ProfileAlreadyCreated();
    ///@notice error emitted when the caller doesn't have a created profile
    error CLCCIPExample_ProfileNotFound();
    ///@notice error emitted when the source chain is not whitelisted and the message should not be allowed
    error CLCCIPExample_SourceChainNotAllowed(uint64 sourceChainSelector);
    ///@notice error emitted when the cross-chain sender is not allowed to perform updates
    error CLCCIPExample_SenderNotAllowed(address sender);
    ///@notice error emitted if the contract doesn't have enough LINK balance to process the transaction
    error CLCCIPExample_NotEnoughBalance(uint256 linkBalance, uint256 fees);

    /*///////////////////////////////////
                Modifiers
    ///////////////////////////////////*/   
    /**
        * @dev Modifier that checks if the chain with the given sourceChainSelector is allowlisted and if the sender is allowlisted.
        * @param _sourceChainSelector The selector of the destination chain.
        * @param _sender The address of the sender.
    */
    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!s_allowlistedSourceChains[_sourceChainSelector]) revert CLCCIPExample_SourceChainNotAllowed(_sourceChainSelector);
        if (s_allowlistedSenders[_sourceChainSelector] != _sender) revert CLCCIPExample_SenderNotAllowed(_sender);
        _;
    }

    /*///////////////////////////////////
                Functions
    ///////////////////////////////////*/

    /*///////////////////////////////////
                constructor
    ///////////////////////////////////*/
    constructor(address _link, address _router, address _owner) CCIPReceiver(_router) Ownable (_owner){
        i_link = IERC20(_link);
    }

    /*///////////////////////////////////
                external
    ///////////////////////////////////*/
    /**
        *@notice Function to create each student cross-chain profile
        *@param _mainnetAddress the mainnet address to receive certificates
        *@dev each wallet should only be able to call it once
    */
    function createStudentCrossChainProfile(address _mainnetAddress) external {
        if(s_userProfile[msg.sender].mainnetAddress != address(0)) revert CLCCIPExample_ProfileAlreadyCreated();
        ///TODO: checks for address(0)
        
        Courses memory course;

        Profile memory profile = Profile ({
                mainnetAddress: _mainnetAddress,
                course: course
        });

        s_userProfile[msg.sender] = profile;

        emit CLCCIPExample_StudentProfileCreated(msg.sender, _mainnetAddress);

        _sendMessage(msg.sender, profile);
    }

    /**
        *@notice Access controlled function to allow ADM's to update Student info
        *@param _student the student that will have information updated
        *@param _newStudentAddress the new wallet information
        *PS: To avoid centralization issues in here, a "request system" could be added
        *The updated would only happen after student approval.
    */
    function updateStudentProfile(address _student, address _newStudentAddress) external onlyOwner {
        ///TODO: checks for address(0)
        s_userProfile[_student].mainnetAddress = _newStudentAddress;
        
        Profile memory profile = s_userProfile[_student];

        emit CLCCIPExample_StudentProfileUpdated(_student, _newStudentAddress);

        _sendMessage(_student, profile);
    }
    
    /**
        * @dev Updates the allowlist status of a source chain
        * @notice This function can only be called by the owner.
        * @param _chainSelector The selector of the source chain to be updated.
        * @param _allowed The allowlist status to be set for the source chain.
    */
    function manageAllowlistSourceChain(uint64 _chainSelector, bool _allowed) external onlyOwner {
        if(_allowed){
            s_allowlistedSourceChains[_chainSelector] = _allowed;
            s_allowlistedReceivers.push(_chainSelector);
        
            emit CLCCIPExample_NewChainAllowlisted(_chainSelector);
        } else {
            uint256 amountOfReceiverChains = s_allowlistedReceivers.length;

            s_allowlistedSourceChains[_chainSelector] = _allowed;

            for(uint256 i = 0; i < amountOfReceiverChains ; ++i){
                if(s_allowlistedReceivers[i] == _chainSelector){
                    s_allowlistedReceivers[i] = s_allowlistedReceivers[amountOfReceiverChains - 1];
                    s_allowlistedReceivers.pop();
                    return;
                }
            }
            emit CLCCIPExample_ChainRemoved(_chainSelector);
        }
    }

    /**
        * @dev Updates the allowlist status of a sender for transactions.
        * @notice This function can only be called by the owner.
        * @param _sourceChainSelector the chain identifier to enable the sender
        * @param _sender The address of the sender to be updated.
    */
    function setAllowlistSender(uint64 _sourceChainSelector, address _sender) external onlyOwner {
        s_allowlistedSenders[_sourceChainSelector] = _sender;

        emit CLCCIPExample_AllowedSenderUpdatedForTheFollowingChain(_sourceChainSelector, _sender);
    }

    /*///////////////////////////////////
                public
    ///////////////////////////////////*/

    /*///////////////////////////////////
                internal
    ///////////////////////////////////*/
    /**
        *@notice standard Chainlink function to process received messages
        *@param _any2EvmMessage the message struct to be processed
    */
    function _ccipReceive(Client.Any2EVMMessage memory _any2EvmMessage)
        internal
        override
        onlyAllowlisted(_any2EvmMessage.sourceChainSelector, abi.decode(_any2EvmMessage.sender, (address)))
    {
        (address student, Profile memory profile) = abi.decode(_any2EvmMessage.data, (address, Profile));

        s_userProfile[student] = profile;

        emit CLCCIPExample_MessageReceived(_any2EvmMessage.messageId, _any2EvmMessage.sourceChainSelector, profile);
    }

    /*///////////////////////////////////
                private
    ///////////////////////////////////*/
    /**
        * @notice Sends data and transfer tokens to receiver on the destination chain.
        * @notice Pay for fees in LINK.
        * @dev Assumes your contract has sufficient LINK to pay for CCIP fees.
        * @param _user The address of the user to be updated
        * @param _profile The user data to be distributed
        * @return messageId_ The ID of the CCIP message that was sent.
    */
    function _sendMessage(address _user, Profile memory _profile) private returns (bytes32 messageId_){
        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        uint256 numberOfChains = s_allowlistedReceivers.length;

        for(uint256 i = 0; i < numberOfChains; ++i){
            uint64 currentChainSelector = s_allowlistedReceivers[i];

            // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
            Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                ///@notice receiver and sender are the same. So we can use the same mapping
                s_allowlistedSenders[currentChainSelector],
                abi.encode(_user, _profile)
            );

            // Get the fee required to send the CCIP message
            uint256 fees = router.getFee(currentChainSelector, evm2AnyMessage);
            
            uint256 linkBalance = i_link.balanceOf(address(this));
            if (fees > linkBalance) revert CLCCIPExample_NotEnoughBalance(linkBalance, fees);
            
            // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
            i_link.approve(address(router), fees);
            
            // Send the message through the router and store the returned message ID
            messageId_ = router.ccipSend(currentChainSelector, evm2AnyMessage);
            
            // Emit an event with message details
            emit CLCCIPExample_MessageSent(messageId_, currentChainSelector, _user, fees);
        }
    }

    /*///////////////////////////////////
                View & Pure
    ///////////////////////////////////*/
    /**
        * @notice Construct a CCIP message.
        * @dev This function will create an EVM2AnyMessage struct with all the necessary information for programmable tokens transfer.
        * @param _crossChainProtocolReceiverContract The address of the receiver.
        * @param _data The encoded struct to update other chains
        * @return message_ Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    */
    function _buildCCIPMessage(
        address _crossChainProtocolReceiverContract,
        bytes memory _data
    ) private view returns (Client.EVM2AnyMessage memory message_) {
        // Set the token amounts
        Client.EVMTokenAmount[] memory tokenAmounts;

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        message_ = Client.EVM2AnyMessage({
            receiver: abi.encode(_crossChainProtocolReceiverContract),
            data: _data,
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(i_link)
        });
    }

    /**
        *@notice Getter function to access user profile info.
        *@param _user the address of the student
        *@return profile_ the student's profile
    */
    function getUserProfileInfo(address _user) external view returns(Profile memory profile_){
        profile_ = s_userProfile[_user];
    }
}
