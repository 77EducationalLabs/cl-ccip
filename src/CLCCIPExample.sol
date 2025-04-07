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

    ///@notice mapping to store student profiles
    mapping(address user => Profile) s_userProfile;
    ///@notice mapping to store the allowlisted chains to send message to this contract
    mapping(uint64 chainSelector => bool isAllowed) s_allowlistedSourceChains;
    ///@notice mapping to store the allowlisted contract to send messages from a specific chain
    mapping(uint64 chainSelector => address sender ) s_allowlistedSenders;

    /*///////////////////////////////////
                Events
    ///////////////////////////////////*/
    ///@notice event emitted when a Student profile is created
    event CLCCIPExample_StudentProfileCreated(address callerTestnetAddress, address mainnetAddress);
    ///@notice event emitted when a Student profile is updated
    event CLCCIPExample_StudentProfileUpdated(address student, address newStudentAddress);
    ///@notice event emitted when a ccip message is received
    event CLCCIPExample_MessageReceived(bytes32 messageId, uint64 sourceChainSelector, Profile profile);

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
        
        Courses memory course;

        s_userProfile[msg.sender] = Profile ({
                mainnetAddress: _mainnetAddress,
                course: course
        });

        emit CLCCIPExample_StudentProfileCreated(msg.sender, _mainnetAddress);
    }

    /**
        *@notice Access controlled function to allow ADM's to update Student info
        *@param _student the student that will have information updated
        *@param _newStudentAddress the new wallet information
        *PS: To avoid centralization issues in here, a "request system" could be added
        *The updated would only happen after student approval.
    */
    function updateStudentProfile(address _student, address _newStudentAddress) external onlyOwner {
        Profile storage profile = s_userProfile[_student];
        
        profile.mainnetAddress = _newStudentAddress;

        emit CLCCIPExample_StudentProfileUpdated(_student, _newStudentAddress);
    }

    /*///////////////////////////////////
                public
    ///////////////////////////////////*/

    /*///////////////////////////////////
                internal
    ///////////////////////////////////*/
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage)
        internal
        override
        onlyAllowlisted(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address)))
    {
        (address student, Profile memory profile) = abi.decode(any2EvmMessage.data, (address, Profile));

        s_userProfile[student] = profile;

        emit CLCCIPExample_MessageReceived(any2EvmMessage.messageId, any2EvmMessage.sourceChainSelector, profile);
    }

    /*///////////////////////////////////
                private
    ///////////////////////////////////*/

    /*///////////////////////////////////
                View & Pure
    ///////////////////////////////////*/

}
